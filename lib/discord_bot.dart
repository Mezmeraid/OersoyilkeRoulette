import 'dart:collection';
import 'dart:math';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

class DiscordBot {
  late final String token;
  late final String? masterTag;
  late final List<String> triggeringMembers;
  late final List<int> unMutableMembersIds;
  late final List<int> guildIds = [];

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

    final commands = CommandsPlugin(
      prefix: (p0) => '!',
      guild: Snowflake(591728990515888128),
    );
    _bot.registerPlugin(commands);
    _bot
      ..registerPlugin(Logging())
      ..registerPlugin(CliIntegration())
      ..registerPlugin(IgnoreExceptions())
      ..connect();

    commands.addCommand(ChatCommand(
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
        }
        else {
          context.respond(MessageBuilder.content('Ca va frère ? tu veux quoi ?'));
        }
      }),
      options: CommandOptions(
        type: CommandType.all,
        defaultResponseLevel: ResponseLevel.private,
        autoAcknowledgeInteractions: true,
      ),
    ));

    _bot.eventsWs.onReady.listen((e) {});

    _bot.eventsWs.onMessageReceived.listen((e) {
      _onMessageReceived(e);
    });
  }

  void initConfig(Map<String, dynamic> config) {
    token = config['token'] as String;
    masterTag = config['masterTag'] as String?;

    final ar = config['triggeringMembers'] as List<dynamic>?;
    triggeringMembers = [];
    ar?.forEach((element) {
      if (element is String) {
        triggeringMembers.add(element);
      }
    });

    final ar2 = config['unMutableMembersIds'] as List<dynamic>?;
    unMutableMembersIds = [];
    ar2?.forEach((element) {
      if (element is int) {
        unMutableMembersIds.add(element);
      }
    });
  }


  Future<void> _updateUsers(IMessageReceivedEvent event) async {
    final guildId = event.message.guild?.id;
    if (guildId == null) {
      return;
    }
    final guildIdInt = guildId.id;
    if (users[guildIdInt] != null && users[guildIdInt]!.isNotEmpty) {
      final authorId = event.message.author.id.id;
      
      if (!users[guildIdInt]!.contains(authorId) && _isMemberMutable(authorId)) {
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
