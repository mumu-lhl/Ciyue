#ifndef RUNNER_SELECTION_CHANNEL_H_
#define RUNNER_SELECTION_CHANNEL_H_

#include <flutter/flutter_engine.h>

// Registers the "ciyue/selection" method channel on the engine's messenger.
// The channel answers getSelectedText / sendCopy / getFocusedAppId for the
// desktop lookup popup; see selection_channel.cpp for the native calls.
void RegisterSelectionChannel(flutter::FlutterEngine* engine);

#endif  // RUNNER_SELECTION_CHANNEL_H_
