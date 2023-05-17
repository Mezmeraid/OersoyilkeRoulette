import 'dart:collection';
import 'dart:math';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

class DiscordBot {
  late final String token;
  late final String? masterTag;
  late final List<String> triggeringMembers;
  late final List<int> unMutableMembersIds;
  late final List<int> guildIds;

  final Map<int, List<int>> users = {};

  final timeoutDuration = Duration(minutes: 5);
  final List<String> _gifsList = [
    'https://media.giphy.com/media/LtFeSxoDE720ZRqu3v/giphy.gif',
    'https://media.giphy.com/media/DTLzZIeBh33S8/giphy.gif',
    'https://media.giphy.com/media/AdbuzBaEVJsyI/giphy.gif',
    'https://tenor.com/view/unicorn-happy-birthday-dance-moves-gif-24459212'
  ];

  late final INyxxWebsocket _bot;
  late final Queue<String> _gifQueue;

  DiscordBot({required Map<String, dynamic> config}) {
    initConfig(config);
    _gifsList.shuffle();
    _gifQueue = Queue.of(_gifsList);

    _bot = NyxxFactory.createNyxxWebsocket(
        token, GatewayIntents.allUnprivileged | GatewayIntents.guildMembers);

    final commandsPlugins = _registerCommandsPlugin();
    _bot
      ..registerPlugin(Logging())
      ..registerPlugin(CliIntegration())
      ..registerPlugin(IgnoreExceptions())
      ..connect();

    _registerCommands(commandsPlugins);

    _bot.eventsWs.onReady.listen((e) {});

    _bot.eventsWs.onMessageReceived.listen((e) {
      _onMessageReceived(e);
    });
  }

  List<CommandsPlugin> _registerCommandsPlugin() {
    List<CommandsPlugin> commandsPlugins = [];

    for (var id in guildIds) {
      final commands = CommandsPlugin(
        prefix: (p0) => '!',
        guild: Snowflake(id),
      );
      _bot.registerPlugin(commands);
      commandsPlugins.add(commands);
    }

    return commandsPlugins;
  }

  void _registerCommands(List<CommandsPlugin> plugins) {
    _registerCommand(plugins, ChatCommand(
      'print_user_list',
      'print the registered user list',
      id('print_user_list', (IChatContext context) {
        if (context.user.tag == masterTag) {
          final userList = users[context.guild?.id.id];
          final sb = StringBuffer("Registered users:\n\n");
          userList?.forEach((element) {
            sb.write('<@$element>\n');
          });
          context.respond(MessageBuilder.content(sb.toString()));
        } else {
          context
              .respond(MessageBuilder.content('Ca va frère ? tu veux quoi ?'));
        }
      }),
      options: CommandOptions(
        type: CommandType.all,
        defaultResponseLevel: ResponseLevel.private,
        autoAcknowledgeInteractions: true,
      ),
    ));
  }

  void _registerCommand(List<CommandsPlugin> plugins, ChatCommand command) {
    for (var plugin in plugins) {
      plugin.addCommand(command);
    }
  }

  void initConfig(Map<String, dynamic> config) {
    token = config['token'] as String;
    masterTag = config['masterTag'] as String?;


    triggeringMembers =
        getListFromJsonDict<String>(jsonDict: config, key: "triggeringMembers");
    unMutableMembersIds = getListFromJsonDict<int>(jsonDict: config, key: "unMutableMembersIds");
    guildIds = getListFromJsonDict<int>(jsonDict: config, key: "guildsIds");
  }

  List<T> getListFromJsonDict<T>({
    required Map<String, dynamic> jsonDict,
    required String key,
  }) {
    final ar = jsonDict[key] as List<dynamic>?;
    final list = <T>[];
    ar?.forEach((element) {
      if (element is T) {
        list.add(element);
      }
    });
    return list;
  }

  Future<void> _updateUsers(IMessageReceivedEvent event) async {
    final guildId = event.message.guild?.id;
    if (guildId == null) {
      return;
    }
    final guildIdInt = guildId.id;
    if (users[guildIdInt] != null && users[guildIdInt]!.isNotEmpty) {
      final authorId = event.message.author.id.id;

      if (!users[guildIdInt]!.contains(authorId) &&
          _isMemberMutable(authorId)) {
        users[guildIdInt]!.add(authorId);
      }
    } else {
      final guild = await _bot.fetchGuild(guildId);

      final memberStream = guild.fetchMembers(limit: 500);
      List<int> members = [];
      await memberStream.forEach((element) {
        if (_isMemberMutable(element.id.id)) {
          members.add(element.id.id);
        }
      });
      users[guildIdInt] = members;
    }
  }

  bool _isMemberMutable(int mbrId) {
    return !unMutableMembersIds.contains(mbrId);
  }

  void _onMessageReceived(IMessageReceivedEvent event) async {
    await _updateUsers(event);

    final guildId = event.message.guild?.id.id;
    if (guildId != null && !guildIds.contains(guildId)) {
      print("unregistered guild $guildId");
    }

    if (_isHunterMessage(event.message)) {
      final random = Random();
      final randomIndex = random.nextInt(1);
      if (randomIndex == 0) {
        print('$randomIndex... pew pew!');
        final timeoutMember = await _timeout(event.message);
        if (timeoutMember != null) {
          _notifyTimeout(
            msg: event.message,
            member: timeoutMember,
            hunter: event.message.member,
          );
        }
      } else {
        print('$randomIndex... lucky you...');
      }
    }
  }

  Future<IMember?> _timeout(IMessage msg) async {
    final guildId = msg.guild?.id;
    if (guildId == null) {
      return null;
    }
    final members = users[guildId.id];
    if (members == null || members.isEmpty) {
      return null;
    }

    final random = Random();
    final randomIndex = random.nextInt(members.length);
    final memberId = members[randomIndex];

    final guild = await _bot.fetchGuild(guildId);
    final memberToTimeout = await guild.fetchMember(Snowflake(memberId));

    memberToTimeout.edit(
        builder: MemberBuilder(
            timeoutUntil: DateTime.now().toUtc().add(Duration(minutes: 5))));

    return memberToTimeout;
  }

  String _pickAGif() {
    final picked = _gifQueue.removeFirst();
    _gifQueue.addLast(picked);
    return picked;
  }

  void _notifyTimeout({
    required IMessage msg,
    required IMember member,
    required IMember? hunter,
  }) async {
    await msg.channel.sendMessage(MessageBuilder.content(
        'Pew Pew Pew ${member.mention} ! Le divin barillet Oersoyilien s\'est '
        'abattu sur toi${hunter != null ? '!\n'
            '${hunter.mention}, dans son infinie sagesse, nous fait grace de tes paroles pendant ${timeoutDuration.inMinutes} minutes 🤤' : ''}'));

    msg.channel.sendMessage(MessageBuilder.content(_pickAGif()));
  }

  bool _isHunterMessage(IMessage msg) =>
      triggeringMembers.contains(msg.author.tag);
}
