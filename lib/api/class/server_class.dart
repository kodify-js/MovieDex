import 'package:moviedex/utils/utils.dart';

class ServerClass {
  String name;
  ServerStatus status;
  ServerClass({
    required this.name,
    this.status = ServerStatus.notTested,
    });
}