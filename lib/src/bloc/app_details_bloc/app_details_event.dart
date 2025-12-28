import 'package:equatable/equatable.dart';

class AppDetailsEvent extends Equatable{
  @override
  List<Object?> get props => [];
  
}


class GetTempleDetail extends AppDetailsEvent{
  final String templeId;

  GetTempleDetail({required this.templeId});
}