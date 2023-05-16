import 'package:oersoyilkroulette/discord_bot.dart';
import 'dart:io';
import 'package:path/path.dart' as p;


void main(List<String> arguments) {
  var filePath = p.join(Directory.current.path, 'bot.token');
  File file = File(filePath);
  var token = file.readAsStringSync();

  DiscordBot(
    token: token,
    huntersTag: [
      'Mezmeraid#4627',
      'Persephoneia la Licorne 🦄💖#0189',
    ],
  );
}
