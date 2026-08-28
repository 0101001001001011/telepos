import 'dart:async';

import 'package:telepos/telegram/bots/bot_command_router.dart';
import 'package:telepos/telegram/bots/bot_manager.dart';
import 'package:telepos/telegram/bots/pos_bot_commands.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class AutoBotDeployer {
  final BotManager _botManager;
  final BotCommandRouter _commandRouter;
  final ChannelRegistry _channelRegistry;
  final TdLibLogger _logger;

  PosBotCommands? _posBotCommands;

  AutoBotDeployer({
    required BotManager botManager,
    required BotCommandRouter commandRouter,
    required ChannelRegistry channelRegistry,
    required TdLibLogger logger,
  }) : _botManager = botManager,
       _commandRouter = commandRouter,
       _channelRegistry = channelRegistry,
       _logger = logger;

  Future<void> deploy({
    required String storeName,
    String? botToken,
    String? botUsername,
  }) async {
    _logger.logConnection('Deploying POS bot for $storeName');

    if (botToken != null && botUsername != null) {
      await _botManager.registerBot(
        botToken: botToken,
        botUsername: botUsername,
      );
    }

    _posBotCommands = PosBotCommands(router: _commandRouter, logger: _logger);
    _posBotCommands!.registerAll();

    final commands = _posBotCommands!.getCommandList();
    await _botManager.setBotCommands(commands);

    for (final channel in _channelRegistry.allChannels) {
      try {
        await _botManager.addBotToChat(channel.chatId);
      } catch (e) {
        _logger.logError('addBotToChannel:${channel.title}', e);
      }
    }

    _commandRouter.startListening();

    _logger.logConnection('POS bot deployed successfully');
  }

  Future<void> updateCommands() async {
    if (_posBotCommands == null) return;
    final commands = _posBotCommands!.getCommandList();
    await _botManager.setBotCommands(commands);
  }
}
