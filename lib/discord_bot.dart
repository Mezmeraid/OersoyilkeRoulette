import 'dart:collection';
import 'dart:math';

import 'package:nyxx/nyxx.dart';

class DiscordBot {
  final String token;
  final List<String> huntersTag;
  final Map<int, List<int>> users = {};
  final excludedUsers = [
    287315981632667651, // Mezmeraid
    1107745966016180344, // this bot
  ];
  final timeoutDuration = Duration(minutes: 5);
  final List<String> _gifsList = [
    'https://media.giphy.com/media/LtFeSxoDE720ZRqu3v/giphy.gif',
    'https://media.giphy.com/media/DTLzZIeBh33S8/giphy.gif',
    'https://media.giphy.com/media/AdbuzBaEVJsyI/giphy.gif',
    'https://tenor.com/view/unicorn-happy-birthday-dance-moves-gif-24459212'
  ];

  late final INyxxWebsocket _bot;
  late final Queue<String> _gifQueue;

  DiscordBot({required this.token, required this.huntersTag}) {
    _gifsList.shuffle();
    _gifQueue = Queue.of(_gifsList);

    _bot = NyxxFactory.createNyxxWebsocket(
        token, GatewayIntents.allUnprivileged | GatewayIntents.guildMembers)
      ..registerPlugin(Logging())
      ..registerPlugin(CliIntegration())
      ..registerPlugin(IgnoreExceptions())
      ..connect();

    // Listen to ready event. Invoked when bot is connected to all shards. Note that cache can be empty or not incomplete.
    _bot.eventsWs.onReady.listen((e) {});

    // Listen to all incoming messages
    _bot.eventsWs.onMessageReceived.listen((e) {
      _onMessageReceived(e);
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
      if (!users[guildIdInt]!.contains(authorId)) {
        users[guildIdInt]!.add(authorId);
      }
    } else {
      final guild = await _bot.fetchGuild(guildId);

      final test = guild.members.values.toList();
      if (test.isNotEmpty) {
        print('OMG member list is not empty ! ${test.length}');
      }

      final memberStream = guild.fetchMembers(limit: 500);
      List<int> members = [];
      await memberStream.forEach((element) {
        if (!excludedUsers.contains(element.id.id)) {
          members.add(element.id.id);
        }
      });
      users[guildIdInt] = members;
    }
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

  bool _isHunterMessage(IMessage msg) => huntersTag.contains(msg.author.tag);
}
