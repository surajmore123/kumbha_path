
import 'dart:ui';

import 'package:flutter/material.dart';

Color textColor = const Color(0xff875FD2);

Color loginButtonLeft = const Color(0xFF885FD2);
Color loginButtonRight = const Color(0xFF493BB8); 
Color dropdown = const Color(0xFF2BA079);
const Color primaryColor = Color.fromRGBO(255, 213, 59, 1.0);


Color launcherLeft = const Color(0xFF5C23C3);
Color launcherRight = const Color(0xFF9048d7);
Color whiteColor = Colors.white;
Color blackColor = Colors.black;
Color redColor = Colors.red;
Color greyColor = Colors.grey;
Color lightblackColor = Colors.black.withOpacity(0.1);
Color bulletColor1 = const Color(0xFFB52776);
Color selectedCountryColor = const Color(0xFF875FD2);
Color statutsBox = const Color(0xFFdb94bc);
Color liveText = const Color(0xFFb12876);
Color pauseBox = const Color(0xFFf7bf90);
Color statusText = const Color(0xFFf17f20);
Color blueArc = const Color(0xFF396AF0);




LinearGradient loginButton = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [loginButtonLeft, loginButtonRight],
);

LinearGradient topUpButton = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [loginButtonRight, loginButtonLeft],
);

LinearGradient launchScreen = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [launcherLeft, launcherRight],
);

LinearGradient followersBox = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [Color(0xFF00E0FF), Color(0xFF0049FF)],
);

final commentBox = LinearGradient(
  colors: [Color(0xFF00FFB2), Color(0xFF00BD4C)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

final sharesBox = LinearGradient(
  colors: [Color(0xFFFFE500), Color(0xFFF07F20)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

final spentBox = LinearGradient(
  colors: [Color(0xFFE36363), Color(0xFFFF7AC4)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

final graphColor = LinearGradient(
  colors: [
    whiteColor,
    Color.fromARGB(255, 34, 170, 125),
  ],
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
);

const whiteBubbleColor = Colors.white;
final purpleGradient = LinearGradient(
  colors: [Color(0xFF6A5AE0), Color(0xFF9C6FE4)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient disabledGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    launcherLeft.withOpacity(0.4),
    launcherRight.withOpacity(0.4),
  ],
);
