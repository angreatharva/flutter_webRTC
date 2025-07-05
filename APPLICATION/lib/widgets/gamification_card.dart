import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../utils/theme_constants.dart';

class GameCard {
  final String title;
  final String description;
  final String lottieAsset;
  final Color color;

  GameCard({
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.color,
  });
}

class GamificationCard extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  
  const GamificationCard({
    Key? key,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
  }) : super(key: key);

  // List of games
  List<GameCard> get games => [
    GameCard(
      title: 'Balloon Risk',
      description: 'Test your risk assessment skills by inflating balloons without popping them.',
      lottieAsset: 'assets/lottie/ballon.json',
      color: ThemeConstants.white.withOpacity(0.8),
    ),
    GameCard(
      title: 'Stroop Test',
      description: 'Challenge your brain by identifying colors when words and colors don\'t match.',
      lottieAsset: 'assets/lottie/color.json',
      color: ThemeConstants.white.withOpacity(0.8),
    ),
    GameCard(
      title: 'Memory Path',
      description: 'Improve your memory by repeating increasingly complex sequences.',
      lottieAsset: 'assets/lottie/path.json',
      color: ThemeConstants.white.withOpacity(0.8),
    ),
    GameCard(
      title: 'Memory Match',
      description: 'Find matching pairs of cards to test and enhance your memory.',
      lottieAsset: 'assets/lottie/memory.json',
      color: ThemeConstants.white.withOpacity(0.8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: Get.height * 0.01),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Get.width * 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Brain Games',
                    style: TextStyle(
                      fontSize: Get.width * 0.05,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Get.width * 0.06),
            child: Text(
              'Improve your cognitive skills with these fun games!',
              style: TextStyle(
                fontSize: Get.width * 0.035,
                color: Colors.grey[700],
              ),
            ),
          ),
          
          // Games grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(Get.width * 0.04),
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
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(GameCard game) {
    return GestureDetector(
      onTap: () {
        // Navigate to the specific game
        if (game.title == 'Balloon Risk') {
          Get.toNamed('/balloon_risk_game');
        } else if (game.title == 'Stroop Test') {
          Get.toNamed('/stroop_test_game');
        } else if (game.title == 'Memory Path') {
          Get.toNamed('/memory_path_game');
        } else if (game.title == 'Memory Match') {
          Get.toNamed('/memory_match_game');
        } else {
          // For other games that are not yet implemented
          Get.snackbar(
            'Coming Soon',
            '${game.title} will be available soon!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: ThemeConstants.mainColor,
            colorText: Colors.white,
          );
        }
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
              height: Get.height * 0.10,
              decoration: BoxDecoration(
                color: game.color,
                shape: BoxShape.circle,
                border: Border.all(color: ThemeConstants.mainColor)
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