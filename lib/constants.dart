library constants;

const bool debug = true;
const String appName = "Relay_server";
const String version = "3.0.0";
const String MSG_HELLO = 'HELLO';
const String MSG_MATCHED = 'MATCHED';
const String MSG_GAMESTATE = 'GAMESTATE';
const String MSG_GAMEOVER = 'GAMEOVER';
const String MSG_GAMEQUIT = 'GAMEQUIT';
const String MSG_CHAT = 'CHAT';
const String MSG_WARNING = 'WARNING';
const String MSG_QUITAPP = 'QUITAPP';
const String MSG_TIMEOUT = 'TIMEOUT';

const int messageLifetimeMs = 7 * 24 * 60 * 60 * 1000;
const int warningDeltaMs = 24 * 60 * 60 * 1000;
