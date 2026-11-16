import 'package:flutter/material.dart';
import 'units/unit_lab.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '캐릭터 움직임 테스트',
    theme: ThemeData.dark(useMaterial3: true),
    home: const UnitLab(),
  ),
);
