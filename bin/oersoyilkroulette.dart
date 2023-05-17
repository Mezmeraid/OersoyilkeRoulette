import 'dart:convert';

import 'package:oersoyilkroulette/discord_bot.dart';
import 'dart:io';
import 'package:path/path.dart' as p;


void main(List<String> arguments) {
  final filePath = p.join(Directory.current.path, 'config.json');
  final file = File(filePath);
  final configAsString = file.readAsStringSync();
  final config = jsonDecode(configAsString) as Map<String, dynamic>;

  DiscordBot(
    config: config,
  );
}
