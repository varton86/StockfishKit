#ifndef STOCKFISH_BRIDGE_H_INCLUDED
#define STOCKFISH_BRIDGE_H_INCLUDED

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct stockfish_engine stockfish_engine_t;

typedef struct stockfish_search_limits {
    int32_t depth;
    int32_t mate;
    uint64_t nodes;
    int32_t move_time_ms;
    int32_t white_time_ms;
    int32_t black_time_ms;
    int32_t white_increment_ms;
    int32_t black_increment_ms;
    int32_t moves_to_go;
} stockfish_search_limits_t;

typedef struct stockfish_search_info {
    int32_t depth;
    int32_t seldepth;
    int32_t multipv;
    int32_t score_cp;
    int32_t mate;
    int32_t time_ms;
    uint64_t nodes;
    uint64_t nps;
    uint64_t tbhits;
    int32_t hashfull;
    const char* bound;
    const char* wdl;
    const char* pv;
} stockfish_search_info_t;

typedef void (*stockfish_info_callback_t)(void* context, const stockfish_search_info_t* info);
typedef void (*stockfish_bestmove_callback_t)(void* context, const char* bestmove, const char* ponder);

stockfish_engine_t* stockfish_engine_create(void);
void stockfish_engine_destroy(stockfish_engine_t* engine);

bool stockfish_engine_set_option(stockfish_engine_t* engine, const char* name, const char* value);
bool stockfish_engine_set_position(
    stockfish_engine_t* engine,
    const char* fen,
    const char* const* moves,
    size_t move_count
);
bool stockfish_engine_search(
    stockfish_engine_t* engine,
    const stockfish_search_limits_t* limits,
    stockfish_info_callback_t info_callback,
    stockfish_bestmove_callback_t bestmove_callback,
    void* context
);
void stockfish_engine_stop(stockfish_engine_t* engine);
const char* stockfish_engine_last_error(const stockfish_engine_t* engine);

#ifdef __cplusplus
}
#endif

#endif
