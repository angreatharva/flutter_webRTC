import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/theme_constants.dart';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({Key? key}) : super(key: key);

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  // Game state variables
  bool _gameStarted = false;
  bool _gameOver = false;
  int _score = 0;
  int _mistakes = 0;
  int _pairsFound = 0;
  int _totalPairs = 8; // 16 cards = 8 pairs
  
  // Timer variables
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _elapsedTime = '00:00';
  
  // Card variables
  late List<CardItem> _cards;
  List<int> _flippedCardIndexes = [];
  bool _processingMatch = false;
  
  // List of icons for the cards
  final List<IconData> _icons = [
    Icons.favorite,
    Icons.star,
    Icons.lightbulb,
    Icons.music_note,
    Icons.local_florist,
    Icons.pets,
    Icons.emoji_emotions,
    Icons.cake,
    Icons.sports_soccer,
    Icons.local_pizza,
    Icons.airplanemode_active,
    Icons.beach_access,
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  @override
  void dispose() {
    if (_gameStarted && !_gameOver) {
      _timer.cancel();
    }
    super.dispose();
  }
  
  void _initializeGame() {
    // Initialize cards
    _cards = _createCards();
    
    // Initialize stopwatch
    _stopwatch = Stopwatch();
    
    // Set initial state
    setState(() {
      _gameStarted = false;
      _gameOver = false;
      _score = 0;
      _mistakes = 0;
      _pairsFound = 0;
      _flippedCardIndexes = [];
      _processingMatch = false;
      _elapsedTime = '00:00';
    });
  }
  
  List<CardItem> _createCards() {
    // Create a list of 8 random icons (for 8 pairs)
    final Random random = Random();
    final List<IconData> selectedIcons = [];
    
    while (selectedIcons.length < _totalPairs) {
      final IconData icon = _icons[random.nextInt(_icons.length)];
      if (!selectedIcons.contains(icon)) {
        selectedIcons.add(icon);
      }
    }
    
    // Create pairs of cards with the selected icons
    final List<CardItem> cards = [];
    for (int i = 0; i < selectedIcons.length; i++) {
      final IconData icon = selectedIcons[i];
      cards.add(CardItem(icon: icon, isMatched: false));
      cards.add(CardItem(icon: icon, isMatched: false));
    }
    
    // Shuffle the cards
    cards.shuffle();
    
    return cards;
  }
  
  void _startGame() {
    setState(() {
      _gameStarted = true;
    });
    
    // Start the stopwatch
    _stopwatch.start();
    
    // Update the timer every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final int minutes = _stopwatch.elapsed.inMinutes;
          final int seconds = _stopwatch.elapsed.inSeconds % 60;
          _elapsedTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        });
      }
    });
  }
  
  void _flipCard(int index) {
    // Don't allow flipping if already processing a match or card is already matched
    if (_processingMatch || _cards[index].isMatched || _flippedCardIndexes.contains(index)) {
      return;
    }
    
    // Start the game on first card flip if not already started
    if (!_gameStarted) {
      _startGame();
    }
    
    setState(() {
      _flippedCardIndexes.add(index);
    });
    
    // If two cards are flipped, check for a match
    if (_flippedCardIndexes.length == 2) {
      _processingMatch = true;
      
      // Check if the two flipped cards match
      final int firstIndex = _flippedCardIndexes[0];
      final int secondIndex = _flippedCardIndexes[1];
      
      if (_cards[firstIndex].icon == _cards[secondIndex].icon) {
        // Match found
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _cards[firstIndex].isMatched = true;
              _cards[secondIndex].isMatched = true;
              _pairsFound++;
              _score += 10; // Award points for a match
              _flippedCardIndexes = [];
              _processingMatch = false;
              
              // Check if all pairs are found
              if (_pairsFound == _totalPairs) {
                _endGame();
              }
            });
          }
        });
      } else {
        // No match
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _mistakes++;
              _flippedCardIndexes = [];
              _processingMatch = false;
            });
          }
        });
      }
    }
  }
  
  void _endGame() {
    _stopwatch.stop();
    _timer.cancel();
    
    setState(() {
      _gameOver = true;
    });
  }
  
  void _restartGame() {
    _initializeGame();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConstants.backgroundColor,
        elevation: 0,
        title: Text(
          'Memory Match Game',
          style: TextStyle(
            color: ThemeConstants.mainColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeConstants.mainColor),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeConstants.backgroundColor,
              Colors.white,
            ],
          ),
        ),
        child: _gameOver ? _buildGameOverScreen() : _buildGameScreen(),
      ),
    );
  }
  
  Widget _buildGameScreen() {
    return Padding(
      padding: EdgeInsets.all(Get.width * 0.04),
      child: Column(
        children: [
          // Score and timer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _score.toString(),
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
                    ),
                  ),
                ],
              ),
              
              // Timer
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Time',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _elapsedTime,
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Pairs found indicator
          Padding(
            padding: EdgeInsets.symmetric(vertical: Get.height * 0.02),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Pairs: ',
                  style: TextStyle(
                    fontSize: Get.width * 0.04,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '$_pairsFound/$_totalPairs',
                  style: TextStyle(
                    fontSize: Get.width * 0.04,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Game instructions
          if (!_gameStarted)
            Padding(
              padding: EdgeInsets.only(bottom: Get.height * 0.02),
              child: Text(
                'Tap any card to start the game',
                style: TextStyle(
                  fontSize: Get.width * 0.04,
                  fontStyle: FontStyle.italic,
                  color: ThemeConstants.mainColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Cards grid
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: Get.width * 0.02,
                mainAxisSpacing: Get.width * 0.02,
                childAspectRatio: 0.7,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return _buildCard(index);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCard(int index) {
    final bool isFlipped = _flippedCardIndexes.contains(index) || _cards[index].isMatched;
    
    return GestureDetector(
      onTap: () => _flipCard(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // Perspective
          ..rotateY(isFlipped ? 3.14159 : 0), // 180 degrees in radians when flipped
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFlipped ? Colors.white : ThemeConstants.secondaryColor,
          borderRadius: BorderRadius.circular(Get.width * 0.02),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isFlipped
            ? Center(
                child: Icon(
                  _cards[index].icon,
                  size: Get.width * 0.08,
                  color: _cards[index].isMatched
                      ? ThemeConstants.secondaryColor
                      : ThemeConstants.accentColor,
                ),
              )
            : Center(
                child: Icon(
                  Icons.question_mark,
                  size: Get.width * 0.08,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
  
  Widget _buildGameOverScreen() {
    // Calculate time in seconds
    final int totalTimeInSeconds = _stopwatch.elapsed.inSeconds;
    
    // Calculate memory score (0-100)
    // Formula: Base score of 100, minus penalties for time and mistakes
    int memoryScore = 100;
    
    // Time penalty: -1 point for every 5 seconds (capped at -50)
    final int timePenalty = (totalTimeInSeconds / 5).floor();
    memoryScore -= timePenalty > 50 ? 50 : timePenalty;
    
    // Mistake penalty: -5 points per mistake (capped at -50)
    final int mistakePenalty = _mistakes * 5;
    memoryScore -= mistakePenalty > 50 ? 50 : mistakePenalty;
    
    // Ensure score is between 0-100
    memoryScore = memoryScore.clamp(0, 100);
    
    // Determine memory assessment
    String memoryAssessment;
    String explanation;
    
    if (memoryScore >= 80) {
      memoryAssessment = 'Excellent';
      explanation = 'You have exceptional short-term memory and concentration. You can quickly identify and remember visual patterns with minimal errors.';
    } else if (memoryScore >= 60) {
      memoryAssessment = 'Good';
      explanation = 'You have good short-term memory and concentration. You can effectively remember visual information with only a few errors.';
    } else if (memoryScore >= 40) {
      memoryAssessment = 'Average';
      explanation = 'You have average short-term memory and concentration. You may benefit from memory exercises to improve recall and reduce errors.';
    } else {
      memoryAssessment = 'Needs Improvement';
      explanation = 'You may have difficulty with short-term memory tasks. This could indicate stress, fatigue, or attention issues affecting your memory recall.';
    }
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Get.width * 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game over title
            Text(
              'Game Completed!',
              style: TextStyle(
                fontSize: Get.width * 0.08,
                fontWeight: FontWeight.bold,
                color: ThemeConstants.mainColor,
              ),
            ),
            SizedBox(height: Get.height * 0.03),
            
            // Score card
            Container(
              padding: EdgeInsets.all(Get.width * 0.06),
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
                children: [
                  // Final score
                  Text(
                    'Final Score',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _score.toString(),
                    style: TextStyle(
                      fontSize: Get.width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.accentColor,
                    ),
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Time taken
                  Text(
                    'Time Taken',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _elapsedTime,
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
                    ),
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Mistakes made
                  Text(
                    'Mistakes Made',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _mistakes.toString(),
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: _mistakes > 10 ? ThemeConstants.dangerColor : ThemeConstants.mainColor,
                    ),
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Memory assessment
                  Text(
                    'Memory Assessment',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    memoryAssessment,
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
                    ),
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Memory score progress
                  LinearProgressIndicator(
                    value: memoryScore / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      memoryScore >= 80
                        ? Colors.green
                        : memoryScore >= 60
                          ? Colors.blue
                          : memoryScore >= 40
                            ? Colors.orange
                            : Colors.red,
                    ),
                    minHeight: Get.height * 0.015,
                    borderRadius: BorderRadius.circular(Get.width * 0.01),
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Explanation
                  Text(
                    explanation,
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: Get.height * 0.03),
            
            // Play again button
            ElevatedButton(
              onPressed: _restartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConstants.mainColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: Get.width * 0.08,
                  vertical: Get.height * 0.02,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Get.width * 0.05),
                ),
              ),
              child: Text(
                'Play Again',
                style: TextStyle(
                  fontSize: Get.width * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardItem {
  final IconData icon;
  bool isMatched;
  
  CardItem({
    required this.icon,
    required this.isMatched,
  });
}