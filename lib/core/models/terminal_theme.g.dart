// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_theme.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TerminalThemeAdapter extends TypeAdapter<TerminalTheme> {
  @override
  final int typeId = 2;

  @override
  TerminalTheme read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TerminalTheme(
      id: fields[0] as String,
      name: fields[1] as String,
      foreground: fields[2] as String,
      background: fields[3] as String,
      cursor: fields[4] as String,
      selection: fields[5] as String,
      colors: (fields[6] as List).cast<String>(),
      isBuiltIn: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      isDefault: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TerminalTheme obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.foreground)
      ..writeByte(3)
      ..write(obj.background)
      ..writeByte(4)
      ..write(obj.cursor)
      ..writeByte(5)
      ..write(obj.selection)
      ..writeByte(6)
      ..write(obj.colors)
      ..writeByte(7)
      ..write(obj.isBuiltIn)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalThemeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
