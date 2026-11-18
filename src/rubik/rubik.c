#include "rubik.h"
#include "rubik_tables.h"

/* Port of the Assignment 1 IDA* solver. Frames keep component ranks rather
 * than full cubes, and the component tables replace per-node re-ranking. */
enum { CUBIES = 7, MAX_DEPTH = 11, MOVES = 9 };

typedef struct {
    uint16_t permutation;
    uint16_t orientation;
    uint8_t next_move;
    uint8_t previous_face;
} search_frame_t;

static const uint8_t face_of[MOVES] = {0, 0, 0, 1, 1, 1, 2, 2, 2};
static const char move_names[MOVES][3] = {"R",  "R2", "R'", "B", "B2",
                                          "B'", "D",  "D2", "D'"};

static int parse_state(const char *input, uint8_t p[CUBIES], uint8_t o[CUBIES])
{
    unsigned seen = 0;
    unsigned twist_sum = 0;

    for (unsigned i = 0; i < 14; ++i) {
        unsigned char digit = (unsigned char) input[i];
        if (i < CUBIES) {
            if (digit < '1' || digit > '7')
                return 0;
            unsigned value = digit - '1';
            unsigned bit = 1u << value;
            if (seen & bit)
                return 0;
            seen |= bit;
            p[i] = (uint8_t) value;
        } else {
            if (digit < '1' || digit > '3')
                return 0;
            unsigned value = digit - '1';
            o[i - CUBIES] = (uint8_t) value;
            twist_sum += value;
        }
    }

    while (twist_sum >= 3)
        twist_sum -= 3;
    return input[14] == '\0' && twist_sum == 0;
}

static uint16_t rank_permutation(const uint8_t p[CUBIES])
{
    static const uint16_t weight[6] = {720, 120, 24, 6, 2, 1};
    unsigned rank = 0;
    for (unsigned i = 0; i < CUBIES - 1; ++i) {
        unsigned smaller = 0;
        for (unsigned j = i + 1; j < CUBIES; ++j)
            smaller += p[j] < p[i];
        rank += smaller * weight[i];
    }
    return (uint16_t) rank;
}

static uint16_t rank_orientation(const uint8_t o[CUBIES])
{
    unsigned rank = 0;
    for (unsigned i = 0; i < CUBIES - 1; ++i)
        rank = (rank << 1) + rank + o[i];
    return (uint16_t) rank;
}

static unsigned heuristic(unsigned p, unsigned o)
{
    unsigned hp = permutation_distance[p];
    unsigned ho = orientation_distance[o];
    return hp > ho ? hp : ho;
}

static int ida_search(uint16_t p,
                      uint16_t o,
                      unsigned limit,
                      uint8_t path[MAX_DEPTH])
{
    search_frame_t frames[MAX_DEPTH + 1];
    unsigned depth = 0;
    frames[0] = (search_frame_t) {p, o, 0, 3};

    for (;;) {
        search_frame_t *current = &frames[depth];
        if (current->next_move == 0) {
            unsigned cp = current->permutation;
            unsigned co = current->orientation;
            if (depth + heuristic(cp, co) > limit) {
                if (depth == 0)
                    return 0;
                --depth;
                continue;
            }
            if (cp == 0 && co == 0)
                return 1;
            if (depth == limit)
                current->next_move = MOVES;
        }

        if (current->next_move >= MOVES) {
            if (depth == 0)
                return 0;
            --depth;
            continue;
        }

        unsigned move = current->next_move++;
        unsigned face = face_of[move];
        if (face == current->previous_face)
            continue;

        path[depth] = (uint8_t) move;
        frames[depth + 1] = (search_frame_t) {
            permutation_next[current->permutation][move],
            orientation_next[current->orientation][move], 0, (uint8_t) face};
        ++depth;
    }
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    uint8_t p[CUBIES], o[CUBIES];
    if (!parse_state(state, p, o))
        return -1;

    uint16_t pr = rank_permutation(p);
    uint16_t ori = rank_orientation(o);
    uint8_t path[MAX_DEPTH] = {0};
    unsigned length = heuristic(pr, ori);
    while (length <= MAX_DEPTH && !ida_search(pr, ori, length, path))
        ++length;

    /* All valid cubes have a solution within MAX_DEPTH. */
    size_t required = 1;
    for (unsigned i = 0; i < length; ++i) {
        required += move_names[path[i]][1] ? 2u : 1u;
        if (i != 0)
            ++required;
    }
    if (cap < required) {
        if (cap != 0)
            out[0] = '\0';
        return -2;
    }

    size_t written = 0;
    for (unsigned i = 0; i < length; ++i) {
        const char *name = move_names[path[i]];
        if (i != 0)
            out[written++] = ' ';
        out[written++] = name[0];
        if (name[1])
            out[written++] = name[1];
    }
    out[written] = '\0';
    return (int) length;
}
