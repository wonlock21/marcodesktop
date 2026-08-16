/// Donanım / yardımcı komut ROS sözleşmesi.
///
/// UI wire kodu bilmez; `AgvService` / bu dosya tek kaynaktır.
library;

/// Topic / tip adları.
abstract final class RosHardwareTopics {
  /// STM32 / yardımcı donanıma giden komut string’i.
  static const cmdHardware = '/cmd_hardware';

  static const buzzerSetEnabled = '/buzzer/set_enabled';
  static const buzzerState = '/buzzer/state';
}

abstract final class RosHardwareTypes {
  static const stringMsg = 'std_msgs/msg/String';
  static const boolMsg = 'std_msgs/msg/Bool';
  static const setBoolSrv = 'std_srvs/srv/SetBool';
}

/// Wire komut sabitleri — widget’lara sızmaz.
abstract final class RosHardwareCommands {
  static const led = 'k312';
}
