import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

class MainLayout extends StatefulWidget {
  final Widget? bottomNavigationBar;
  final Widget? body;
  final bool? showDefaultBottom;
  final bool? showCurvedAppBar;
  final bool? showFloatingActionButton;
  final String? title;
  final PreferredSizeWidget? appBar; // 👈 NEW

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
    this.appBar, // 👈 NEW
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
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,

      appBar: widget.appBar, // 👈 USE IT HERE

      body: widget.body,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: (widget.showFloatingActionButton == false)
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
                    // gradient: topUpButton,
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
      bottomNavigationBar: (widget.showDefaultBottom != true)
          ? null
          : ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                backgroundColor: whiteColor,
                type: BottomNavigationBarType.fixed,
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
                        Navigator.pushNamed(context, '/aichat');
                      }
                      break;
                    case 2:
                      if (widget.ctx != 2) {
                        Navigator.pushNamed(context, '/shahiEvents');
                      }
                      break;
                    case 3:
                      if (widget.ctx != 3) {
                        Navigator.pushNamed(context, '/journal');
                      }
                      break;
                  }
                },
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: Image.asset('assets/icons/home.png', height: 24, width: 24),
                    activeIcon: Image.asset('assets/icons/home.png', height: 24, width: 24),
                    label: 'Home',
                  ),
                    BottomNavigationBarItem(
                    icon: Image.asset('assets/icons/community.png', height: 24, width: 24),
                    activeIcon: Image.asset('assets/icons/community.png', height: 24, width: 24),
                    label: 'AI Chat',
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset('assets/icons/event.png', height: 24, width: 24),
                    activeIcon: Image.asset('assets/icons/event.png', height: 24, width: 24),
                    label: 'Events',
                  ),
                
                  BottomNavigationBarItem(
                    icon: Image.asset('assets/icons/note.png', height: 24, width: 24),
                    activeIcon: Image.asset('assets/icons/note.png', height: 24, width: 24),
                    label: 'Journal',
                  ),
                ],
              ),
            ),
    );
  }
}

