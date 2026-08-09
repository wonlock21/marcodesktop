/// Donanım / yardımcı komut ROS sözleşmesi (LED, buzzer, parametre stringleri).
///
/// UI wire kodu bilmez; `AgvService` / bu dosya tek kaynaktır.
library;

/// Topic / tip adları.
abstract final class RosHardwareTopics {
  /// STM32 / yardımcı donanıma giden komut string’i.
  static const cmdHardware = '/cmd_hardware';
}

abstract final class RosHardwareTypes {
  static const stringMsg = 'std_msgs/msg/String';
}

/// Wire komut sabitleri — widget’lara sızmaz.
abstract final class RosHardwareCommands {
  static const led = 'k312';
  static const buzzer = 'k313';
}
