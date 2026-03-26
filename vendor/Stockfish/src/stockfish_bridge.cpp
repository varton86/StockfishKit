#include "include/stockfish_bridge.h"

#include <mutex>
#include <new>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "bitboard.h"
#include "engine.h"
#include "position.h"
#include "score.h"
#include "tune.h"
#include "ucioption.h"

using namespace Stockfish;

namespace {

std::once_flag initialization_flag;

void initialize_stockfish() {
    Bitboards::init();
    Position::init();
}

std::string format_score(const Score& score) {
    constexpr int tablebaseCP = 20000;

    return score.visit(
      [](auto value) -> std::string {
          using T = std::decay_t<decltype(value)>;

          if constexpr (std::is_same_v<T, Score::Mate>)
          {
              const auto mate = (value.plies > 0 ? (value.plies + 1) : value.plies) / 2;
              return std::to_string(mate);
          }
          else if constexpr (std::is_same_v<T, Score::Tablebase>)
          {
              const auto cp = value.win ? tablebaseCP - value.plies : -tablebaseCP - value.plies;
              return std::to_string(cp);
          }
          else
          {
              return std::to_string(value.value);
          }
      });
}

stockfish_search_info_t make_search_info(const Engine::InfoShort& info) {
    stockfish_search_info_t result {};
    result.depth = info.depth;

    info.score.visit([&result](auto value) {
        using T = std::decay_t<decltype(value)>;

        if constexpr (std::is_same_v<T, Score::Mate>)
        {
            result.mate = (value.plies > 0 ? (value.plies + 1) : value.plies) / 2;
        }
        else if constexpr (std::is_same_v<T, Score::Tablebase>)
        {
            constexpr int tablebaseCP = 20000;
            result.score_cp = value.win ? tablebaseCP - value.plies : -tablebaseCP - value.plies;
        }
        else
        {
            result.score_cp = value.value;
        }
    });

    return result;
}

Search::LimitsType make_limits(const stockfish_search_limits_t& limits) {
    Search::LimitsType result;
    result.depth = limits.depth;
    result.mate = limits.mate;
    result.nodes = limits.nodes;
    result.movetime = limits.move_time_ms;
    result.time[WHITE] = limits.white_time_ms;
    result.time[BLACK] = limits.black_time_ms;
    result.inc[WHITE] = limits.white_increment_ms;
    result.inc[BLACK] = limits.black_increment_ms;
    result.movestogo = limits.moves_to_go;
    result.startTime = now();
    return result;
}

}  // namespace

struct stockfish_engine {
    stockfish_engine() {
        std::call_once(initialization_flag, initialize_stockfish);
        engine = std::make_unique<Engine>(std::string("stockfish-spm"));
        Tune::init(engine->get_options());
    }

    std::unique_ptr<Engine> engine;
    std::mutex state_mutex;
    std::string last_error;
    bool searching = false;
};

extern "C" {

stockfish_engine_t* stockfish_engine_create(void) {
    return new (std::nothrow) stockfish_engine();
}

void stockfish_engine_destroy(stockfish_engine_t* engine) {
    delete engine;
}

bool stockfish_engine_set_option(stockfish_engine_t* engine, const char* name, const char* value) {
    if (engine == nullptr || name == nullptr || value == nullptr)
    {
        return false;
    }

    std::lock_guard<std::mutex> lock(engine->state_mutex);

    if (engine->searching)
    {
        engine->last_error = "Cannot change options while a search is running.";
        return false;
    }

    if (engine->engine->get_options().count(name) == 0)
    {
        engine->last_error = "Unknown option: ";
        engine->last_error += name;
        return false;
    }

    std::istringstream stream(std::string("name ") + name + " value " + value);
    engine->engine->get_options().setoption(stream);
    engine->last_error.clear();
    return true;
}

bool stockfish_engine_set_position(
  stockfish_engine_t* engine,
  const char* fen,
  const char* const* moves,
  size_t move_count
) {
    if (engine == nullptr || fen == nullptr)
    {
        return false;
    }

    std::lock_guard<std::mutex> lock(engine->state_mutex);

    if (engine->searching)
    {
        engine->last_error = "Cannot change the position while a search is running.";
        return false;
    }

    std::vector<std::string> move_list;
    move_list.reserve(move_count);

    for (size_t index = 0; index < move_count; ++index)
    {
        if (moves[index] != nullptr)
        {
            move_list.emplace_back(moves[index]);
        }
    }

    const auto error = engine->engine->set_position(fen, move_list);
    if (error.has_value())
    {
        engine->last_error = error->what();
        return false;
    }

    engine->last_error.clear();
    return true;
}

bool stockfish_engine_search(
  stockfish_engine_t* engine,
  const stockfish_search_limits_t* limits,
  stockfish_info_callback_t info_callback,
  stockfish_bestmove_callback_t bestmove_callback,
  void* context
) {
    if (engine == nullptr || limits == nullptr)
    {
        return false;
    }

    {
        std::lock_guard<std::mutex> lock(engine->state_mutex);

        if (engine->searching)
        {
            engine->last_error = "A search is already running for this engine instance.";
            return false;
        }

        engine->searching = true;
        engine->last_error.clear();
    }

    engine->engine->set_on_update_no_moves([info_callback, context](const Engine::InfoShort& info) {
        if (info_callback == nullptr)
        {
            return;
        }

        const auto bridge_info = make_search_info(info);
        info_callback(context, &bridge_info);
    });

    engine->engine->set_on_update_full([info_callback, context](const Engine::InfoFull& info) {
        if (info_callback == nullptr)
        {
            return;
        }

        auto bridge_info = make_search_info(info);
        bridge_info.seldepth = info.selDepth;
        bridge_info.multipv = static_cast<int32_t>(info.multiPV);
        bridge_info.time_ms = static_cast<int32_t>(info.timeMs);
        bridge_info.nodes = info.nodes;
        bridge_info.nps = info.nps;
        bridge_info.tbhits = info.tbHits;
        bridge_info.hashfull = info.hashfull;

        const std::string bound(info.bound);
        const std::string wdl(info.wdl);
        const std::string pv(info.pv);

        bridge_info.bound = bound.empty() ? nullptr : bound.c_str();
        bridge_info.wdl = wdl.empty() ? nullptr : wdl.c_str();
        bridge_info.pv = pv.empty() ? nullptr : pv.c_str();

        info_callback(context, &bridge_info);
    });

    engine->engine->set_on_bestmove([bestmove_callback, context](std::string_view bestmove, std::string_view ponder) {
        if (bestmove_callback == nullptr)
        {
            return;
        }

        const std::string bestmove_string(bestmove);
        const std::string ponder_string(ponder);

        bestmove_callback(
          context,
          bestmove_string.c_str(),
          ponder_string.empty() ? nullptr : ponder_string.c_str()
        );
    });

    engine->engine->set_on_verify_networks([](std::string_view) {});

    auto search_limits = make_limits(*limits);
    engine->engine->go(search_limits);
    engine->engine->wait_for_search_finished();

    {
        std::lock_guard<std::mutex> lock(engine->state_mutex);
        engine->searching = false;
    }

    return true;
}

void stockfish_engine_stop(stockfish_engine_t* engine) {
    if (engine == nullptr)
    {
        return;
    }

    engine->engine->stop();
}

const char* stockfish_engine_last_error(const stockfish_engine_t* engine) {
    if (engine == nullptr || engine->last_error.empty())
    {
        return nullptr;
    }

    return engine->last_error.c_str();
}

}  // extern "C"
