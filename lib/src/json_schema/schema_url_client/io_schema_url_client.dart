import 'dart:convert';
import 'dart:io';
import 'dart:convert' as convert;

import 'package:json_schema/src/json_schema/constants.dart';
import 'package:json_schema/src/json_schema/json_schema.dart';
import 'package:json_schema/src/json_schema/utils.dart';
import 'package:json_schema/src/json_schema/schema_url_client/schema_url_client.dart';
import 'package:rfc_6901/rfc_6901.dart';

class IoSchemaUrlClient extends SchemaUrlClient {
  @override
  createFromUrl(String schemaUrl, {SchemaVersion schemaVersion}) async {
    final uriWithFrag = Uri.parse(schemaUrl);
    final uri = schemaUrl.endsWith('#') ? uriWithFrag : uriWithFrag.removeFragment();
    Map schemaMap;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      // Setup the HTTP request.
      final httpRequest = await HttpClient().getUrl(uri);
      httpRequest.followRedirects = true;
      // Fetch the response
      final response = await httpRequest.close();
      // Convert the response into a string
      if (response.statusCode == HttpStatus.notFound) {
        throw ArgumentError('Schema at URL: $schemaUrl can\'t be found.');
      }
      final schemaText = await convert.Utf8Decoder().bind(response).join();
      schemaMap = json.decode(schemaText);
    } else if (uri.scheme == 'file' || uri.scheme == '') {
      final fileString = await File(uri.scheme == 'file' ? uri.toFilePath() : schemaUrl).readAsString();
      schemaMap = json.decode(fileString);
    } else {
      throw FormatException('Url schema must be http, file, or empty: $schemaUrl');
    }
    // HTTP servers / file systems ignore fragments, so resolve a sub-map if a fragment was specified.
    final parentSchema = await JsonSchema.createAsync(schemaMap, schemaVersion: schemaVersion, fetchedFromUri: uri);
    final schema = JsonSchemaUtils.getSubMapFromFragment(parentSchema, uriWithFrag);
    return schema ?? parentSchema;
  }

  @override
  Future<Map<String, dynamic>> getSchemaJsonFromUrl(String schemaUrl) async {
    final uriWithFrag = Uri.parse(schemaUrl);
    final uri = schemaUrl.endsWith('#') ? uriWithFrag : uriWithFrag.removeFragment();
    Map schemaMap;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      // Setup the HTTP request.
      final httpRequest = await HttpClient().getUrl(uri);
      httpRequest.followRedirects = true;
      // Fetch the response
      final response = await httpRequest.close();
      // Convert the response into a string
      if (response.statusCode == HttpStatus.notFound) {
        throw ArgumentError('Schema at URL: $schemaUrl can\'t be found.');
      }
      final schemaText = await convert.Utf8Decoder().bind(response).join();
      schemaMap = json.decode(schemaText);
    } else if (uri.scheme == 'file' || uri.scheme == '') {
      final fileString = await File(uri.scheme == 'file' ? uri.toFilePath() : schemaUrl).readAsString();
      schemaMap = json.decode(fileString);
    } else {
      throw FormatException('Url schema must be http, file, or empty: $schemaUrl');
    }
    // HTTP servers ignore fragments, so resolve a sub-map if a fragment was specified.
    var subSchema;
    try {
      subSchema = JsonPointer(uriWithFrag.fragment)?.read(schemaMap);
    } catch (_) {
      // Do nothing if we fail to decode or read the pointer.
    }
    return subSchema ?? schemaMap;
  }
}

SchemaUrlClient createClient() => IoSchemaUrlClient();
