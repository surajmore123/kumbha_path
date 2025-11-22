import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

class MainLayout extends StatefulWidget {
  final Widget? bottomNavigationBar;
  final Widget? body;
  final bool? showDefaultBottom;
  final bool? showCurvedAppBar;
  final bool? showFloatingActionButton;
  final String? title;

  int ctx;
  MainLayout({
    super.key,
    this.bottomNavigationBar,
    this.showDefaultBottom = false,
    this.ctx = 0,
    this.showCurvedAppBar = false,
    this.body,
    this.showFloatingActionButton = false,
    this.title,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double paddingFactor = screenWidth < 600 ? 0.05 : 0.03;

    return Scaffold(
      backgroundColor: Colors.amber,
      resizeToAvoidBottomInset: true,
      body: widget.body,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton:
          (widget.showFloatingActionButton == false)
              ? null
              : Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: paddingFactor * screenHeight,
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 55,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      //gradient: topUpButton,
                    ),
                    child: Center(
                      child: Text(
                        widget.title.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.04,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      bottomNavigationBar:
          (widget.showDefaultBottom != true)
              ? null
              : ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    color: whiteColor,
                    border: Border(
                      top: BorderSide(color: blackColor.withOpacity(0.1)),
                    ),
                  ),
                  child: BottomNavigationBar(
                    backgroundColor: whiteColor,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: textColor,
                    unselectedItemColor: greyColor,
                    selectedFontSize: screenWidth * 0.03,
                    unselectedFontSize: screenWidth * 0.03,
                    currentIndex: widget.ctx,
                    onTap: (int value) async {
                      switch (value) {
                        case 0:
                          if (widget.ctx != 0) {
                            Navigator.pushNamed(context, '/dashboardScreen');
                          }
                          break;
                        case 1:
                          if (widget.ctx != 1) {
                            Navigator.pushNamed(context, '/campaignHistory');
                          }
                          break;
                        case 2:
                          if (widget.ctx != 2) {
                            Navigator.pushNamed(context, '/getStartScreen');
                          }
                          break;
                        case 3:
                          if (widget.ctx != 3) {
                            Navigator.pushNamed(context, '/tutorialScreen');
                          }
                          break;
                        case 4:
                          if (widget.ctx != 4) {
                            Navigator.pushNamed(context, '/settingScreen');
                          }
                          break;
                      }
                    },
                    items: <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                        icon: Image.asset(
                          'assets/icons/home.png',
                          color: greyColor,
                        ),
                        label: 'Home',
                        activeIcon: GestureDetector(
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => const DashBoardScreen(),
                            //   ),
                            // );
                          },
                          child: Image.asset(
                            'assets/icons/home.png',
                            color: textColor,
                          ),
                        ),
                      ),
                      BottomNavigationBarItem(
                        icon: Image.asset(
                          'assets/icons/home.png',
                          color: greyColor,
                        ),
                        label: 'Events',
                        activeIcon: GestureDetector(
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   // MaterialPageRoute(
                            //   //   builder: (context) => const CampaignHistory(),
                            //   // ),
                            // );
                          },
                          child: Image.asset(
                            'assets/icons/home.png',
                            color: textColor,
                          ),
                        ),
                      ),
                      BottomNavigationBarItem(
                        icon: Image.asset(
                          'assets/icons/home.png',
                          color: greyColor,
                        ),
                        label: 'Community',
                        activeIcon: GestureDetector(
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder:
                            //         (context) => const ChatGetStartScreen(),
                            //   ),
                            // );
                          },
                          child: Image.asset(
                            'assets/icons/home.png',
                            color: textColor,
                          ),
                        ),
                      ),
                      BottomNavigationBarItem(
                        icon: Image.asset(
                          'assets/icons/home.png',
                          color: greyColor,
                        ),
                        label: 'Journal',
                        activeIcon: GestureDetector(
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => const TutorialScreen(),
                            //   ),
                            // );
                          },
                          child: Image.asset(
                            'assets/icons/home.png',
                            color: textColor,
                          ),
                        ),
                      ),
                      // BottomNavigationBarItem(
                      //   icon: Image.asset(
                      //     'assets/icons/setting.png',
                      //     color: greyColor,
                      //   ),
                      //   label: 'Settings',
                      //   activeIcon: GestureDetector(
                      //     onTap: () {
                      //       // Navigator.push(
                      //       //   context,
                      //       //   MaterialPageRoute(
                      //       //     builder: (context) => const SettingScreen(),
                      //       //   ),
                      //       // );
                      //     },
                      //     child: Image.asset(
                      //       'assets/icons/setting.png',
                      //       color: textColor,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
    );
  }
}
