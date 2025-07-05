import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../../controllers/navigation_controller.dart';
import '../../controllers/user_controller.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/custom_bottom_nav.dart';



class GameCard {
  final String title;
  final String description;
  final String lottieAsset; // Changed from IconData to String for Lottie asset path
  final Color color;

  GameCard({
    required this.title,
    required this.description,
    required this.lottieAsset, // Changed parameter name
    required this.color,
  });
}

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({Key? key}) : super(key: key);

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  final UserController userController = Get.find<UserController>();
  bool isAuthenticated = false;

  // List of games
  final List<GameCard> games = [
    GameCard(
      title: 'Balloon Risk',
      description: 'Test your risk assessment skills by inflating balloons without popping them.',
      lottieAsset: 'assets/lottie/ballon.json',
      color: ThemeConstants.mainColor.withOpacity(0.8),
    ),
    GameCard(
      title: 'Stroop Test',
      description: 'Challenge your brain by identifying colors when words and colors don\'t match.',
      lottieAsset: 'assets/lottie/color.json',
      color: ThemeConstants.mainColor.withOpacity(0.8),
    ),
    GameCard(
      title: 'Memory Path',
      description: 'Improve your memory by repeating increasingly complex sequences.',
      lottieAsset: 'assets/lottie/path.json',
      color: ThemeConstants.mainColor.withOpacity(0.8),
    ),
    GameCard(
      title: 'Memory Match',
      description: 'Find matching pairs of cards to test and enhance your memory.',
      lottieAsset: 'assets/lottie/memory.json',
      color: ThemeConstants.mainColor.withOpacity(0.8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // Update navigation index
    Get.find<NavigationController>().updateIndexFromRoute('/gamification');
    
    // Validate user outside of build method
    _checkAuthentication();
  }
  
  void _checkAuthentication() {
    // Check authentication status
    isAuthenticated = userController.user.value != null && userController.isLoggedIn.value;
    
    if (!isAuthenticated) {
      // Use Future.delayed to push validation outside of current execution cycle
      Future.delayed(Duration.zero, () {
        if (mounted) userController.validateUser();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      // Show a loading indicator while authentication is checked
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: ThemeConstants.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConstants.backgroundColor,
        elevation: 0,
        toolbarHeight: Get.height * 0.08,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() => Text(
              'Welcome ${userController.isDoctor ? "Dr." : ""} ${userController.userName}',
              style: TextStyle(
                color: ThemeConstants.accentColor,
                fontSize: Get.width * 0.04,
                fontWeight: FontWeight.w500,
              ),
            )),
            Text(
              'Brain Games',
              style: TextStyle(
                color: ThemeConstants.mainColor,
                fontSize: Get.width * 0.05,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Get.width * 0.04,
          vertical: Get.height * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header text
            Padding(
              padding: EdgeInsets.only(bottom: Get.height * 0.02),
              child: Text(
                'Improve your cognitive skills with these fun games!',
                style: TextStyle(
                  fontSize: Get.width * 0.045,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Games grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: Get.width * 0.04,
                  mainAxisSpacing: Get.width * 0.04,
                  childAspectRatio: 0.8,
                ),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  return _buildGameCard(games[index]);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildGameCard(GameCard game) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to the specific game
        Get.snackbar(
          'Coming Soon',
          '${game.title} will be available soon!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ThemeConstants.mainColor,
          colorText: Colors.white,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Get.width * 0.05),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game animation
            Container(
              width: Get.width * 0.15,
              height: Get.width * 0.15,
              decoration: BoxDecoration(
                color: game.color,
                shape: BoxShape.circle,
              ),
              child: Lottie.asset(
                game.lottieAsset,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: Get.height * 0.01),
            
            // Game title
            Text(
              game.title,
              style: TextStyle(
                fontSize: Get.width * 0.045,
                fontWeight: FontWeight.bold,
                color: ThemeConstants.mainColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Get.height * 0.005),
            
            // Game description
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Get.width * 0.02),
              child: Text(
                game.description,
                style: TextStyle(
                  fontSize: Get.width * 0.03,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}