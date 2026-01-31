// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_connection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WebSocketConnectionAdapter extends TypeAdapter<WebSocketConnection> {
  @override
  final int typeId = 1;

  @override
  WebSocketConnection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WebSocketConnection(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      headers: (fields[3] as Map?)?.cast<String, String>(),
      queryParams: (fields[4] as Map?)?.cast<String, dynamic>(),
      protocol: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      lastConnectedAt: fields[7] as DateTime?,
      isFavorite: fields[8] as bool,
      extraConfig: (fields[9] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, WebSocketConnection obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.headers)
      ..writeByte(4)
      ..write(obj.queryParams)
      ..writeByte(5)
      ..write(obj.protocol)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastConnectedAt)
      ..writeByte(8)
      ..write(obj.isFavorite)
      ..writeByte(9)
      ..write(obj.extraConfig);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSocketConnectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
