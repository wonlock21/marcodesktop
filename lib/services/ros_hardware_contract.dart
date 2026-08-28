/// Donanım / yardımcı komut ROS sözleşmesi.
///
/// UI wire kodu bilmez; `AgvService` / bu dosya tek kaynaktır.
library;

/// Topic / tip adları.
abstract final class RosHardwareTopics {
  static const buzzerSetEnabled = '/buzzer/set_enabled';
  static const buzzerState = '/buzzer/state';
}

abstract final class RosHardwareTypes {
  static const boolMsg = 'std_msgs/msg/Bool';
  static const setBoolSrv = 'std_srvs/srv/SetBool';
}
