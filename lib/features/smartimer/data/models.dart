import 'package:hive/hive.dart';

class SmartiTask {
  String id;
  String title;
  DateTime scheduledTime;
  bool isCompleted;
  String category;

  SmartiTask({
    required this.id,
    required this.title,
    required this.scheduledTime,
    this.isCompleted = false,
    this.category = 'Mental',
  });
}

class SmartiTaskAdapter extends TypeAdapter<SmartiTask> {
  @override
  final int typeId = 10;

  @override
  SmartiTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SmartiTask(
      id: fields[0] as String,
      title: fields[1] as String,
      scheduledTime: fields[2] as DateTime,
      isCompleted: fields[3] as bool,
      category: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SmartiTask obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.scheduledTime)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.category);
  }
}

class SmartiGoal {
  String id;
  String title;
  String description;

  SmartiGoal({
    required this.id,
    required this.title,
    required this.description,
  });
}

class SmartiGoalAdapter extends TypeAdapter<SmartiGoal> {
  @override
  final int typeId = 11;

  @override
  SmartiGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SmartiGoal(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SmartiGoal obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description);
  }
}
