import 'dart:convert';
import 'dart:io';

import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

Future<void> main(List<String> args) async {
  if (args.length != 5) {
    exit(1);
  }

  final address = args[0];
  final msg = HEX.decode(HEX.encode(Utf8Encoder().convert(args[1])));
  final pubKey = HEX.decode(args[2]);
  final signature = HEX.decode(args[3]);
  final nodeUrl = args[4];

  final isValidSignature = (await Crypto.verify(signature, msg, pubKey)) &&
      Address.fromPublicKey(pubKey).toString() == address;

  if (!isValidSignature) {
    print(jsonEncode({
      'is_valid_signature': isValidSignature,
      'is_pillar': false,
      'pillar_name': '',
      'is_sentinel': false,
    }));
    exit(0);
  }

  final httpClient = http.Client();

  final pillarName =
      await tryGetPillarNameFromAddress(httpClient, nodeUrl, address);
  final sentinelAddress =
      await tryGetSentinelFromAddress(httpClient, nodeUrl, address);

  print(jsonEncode({
    'is_valid_signature': isValidSignature,
    'is_pillar': pillarName.isNotEmpty,
    'pillar_name': pillarName,
    'is_sentinel': sentinelAddress.isNotEmpty,
  }));

  exit(0);
}

Future<String> tryGetPillarNameFromAddress(
    http.Client client, String nodeUrl, String address) async {
  final response = await client.post(
    Uri.parse(nodeUrl),
    body: json.encode({
      "jsonrpc": "2.0",
      "id": 3,
      "method": "embedded.pillar.getAll",
      "params": [0, 1000]
    }),
    headers: <String, String>{'Content-Type': 'application/json'},
  );

  final pillars = json.decode(response.body)['result']['list'];

  String pillarName = '';
  for (final pillar in pillars) {
    if (pillar['ownerAddress'] == address) {
      pillarName = pillar['name'];
      break;
    }
  }

  return pillarName;
}

Future<String> tryGetSentinelFromAddress(
    http.Client client, String nodeUrl, String address) async {
  final response = await client.post(
    Uri.parse(nodeUrl),
    body: json.encode({
      "jsonrpc": "2.0",
      "id": 3,
      "method": "embedded.sentinel.getAllActive",
      "params": [0, 1000]
    }),
    headers: <String, String>{'Content-Type': 'application/json'},
  );

  final sentinels = json.decode(response.body)['result']['list'];

  String sentinelAddress = '';
  for (final sentinel in sentinels) {
    if (sentinel['owner'] == address) {
      sentinelAddress = sentinel['owner'];
      break;
    }
  }

  return sentinelAddress;
}
