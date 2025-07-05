import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/theme_constants.dart';

class StroopTestGame extends StatefulWidget {
  const StroopTestGame({Key? key}) : super(key: key);

  @override
  State<StroopTestGame> createState() => _StroopTestGameState();
}

class _StroopTestGameState extends State<StroopTestGame> {
  // Game state variables
  int _score = 0;
  int _round = 0;
  int _totalRounds = 20;
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  bool _gameOver = false;
  
  // Timer variables
  late Timer _timer;
  int _timeLeft = 60; // 60 seconds game
  
  // Current word and color
  String _currentWord = '';
  Color _currentColor = Colors.black;
  List<String> _colorOptions = [];
  
  // Available colors for the game
  final Map<String, Color> _colors = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Yellow': Colors.yellow,
    'Purple': Colors.purple,
    'Orange': Colors.orange,
  };
  
  // Random generator
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    _startGame();
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  void _startGame() {
    _startTimer();
    _generateNewRound();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _endGame();
        }
      });
    });
  }
  
  void _generateNewRound() {
    if (_round >= _totalRounds) {
      _endGame();
      return;
    }
    
    // Get list of color names
    List<String> colorNames = _colors.keys.toList();
    
    // Select a random color name for the word
    String wordText = colorNames[_random.nextInt(colorNames.length)];
    
    // Select a different random color for the display
    List<String> remainingColors = List.from(colorNames);
    remainingColors.remove(wordText); // Remove the word to ensure conflict
    String colorName = remainingColors[_random.nextInt(remainingColors.length)];
    Color displayColor = _colors[colorName]!;
    
    // Generate 4 color options (including the correct one)
    List<String> options = [];
    options.add(colorName); // Add correct color
    
    // Add 3 random incorrect options
    List<String> incorrectOptions = List.from(colorNames);
    incorrectOptions.remove(colorName); // Remove correct answer
    incorrectOptions.shuffle();
    options.addAll(incorrectOptions.take(3));
    
    // Shuffle options
    options.shuffle();
    
    setState(() {
      _currentWord = wordText;
      _currentColor = displayColor;
      _colorOptions = options;
      _round++;
    });
  }
  
  void _checkAnswer(String selectedColor) {
    // Get the name of the current display color
    String correctColorName = '';
    _colors.forEach((name, color) {
      if (color == _currentColor) {
        correctColorName = name;
      }
    });
    
    if (selectedColor == correctColorName) {
      // Correct answer
      setState(() {
        _score += 10;
        _correctAnswers++;
      });
    } else {
      // Incorrect answer
      setState(() {
        _incorrectAnswers++;
      });
    }
    
    // Generate new round
    _generateNewRound();
  }
  
  void _endGame() {
    _timer.cancel();
    setState(() {
      _gameOver = true;
    });
  }
  
  void _restartGame() {
    setState(() {
      _score = 0;
      _round = 0;
      _correctAnswers = 0;
      _incorrectAnswers = 0;
      _gameOver = false;
      _timeLeft = 60;
    });
    _startGame();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConstants.backgroundColor,
        elevation: 0,
        title: Text(
          'Stroop Test Game',
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
                    'Time Left',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '$_timeLeft s',
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: _timeLeft > 10 ? ThemeConstants.accentColor : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Round counter
          Padding(
            padding: EdgeInsets.symmetric(vertical: Get.height * 0.02),
            child: Text(
              'Round $_round of $_totalRounds',
              style: TextStyle(
                fontSize: Get.width * 0.04,
                color: Colors.grey[700],
              ),
            ),
          ),
          
          // Instructions
          Padding(
            padding: EdgeInsets.symmetric(vertical: Get.height * 0.02),
            child: Text(
              'Tap the actual COLOR of the word, not what the word says!',
              style: TextStyle(
                fontSize: Get.width * 0.04,
                fontWeight: FontWeight.bold,
                color: ThemeConstants.mainColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // The colored word
          Expanded(
            child: Center(
              child: Text(
                _currentWord,
                style: TextStyle(
                  fontSize: Get.width * 0.15,
                  fontWeight: FontWeight.bold,
                  color: _currentColor,
                ),
              ),
            ),
          ),
          
          // Color options
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            childAspectRatio: 2.5,
            mainAxisSpacing: Get.height * 0.02,
            crossAxisSpacing: Get.width * 0.04,
            children: _colorOptions.map((colorName) {
              return ElevatedButton(
                onPressed: () => _checkAnswer(colorName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ThemeConstants.mainColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Get.width * 0.02),
                    side: BorderSide(
                      color: ThemeConstants.mainColor,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  colorName,
                  style: TextStyle(
                    fontSize: Get.width * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameOverScreen() {
    // Calculate accuracy percentage
    double accuracy = _correctAnswers > 0 
        ? (_correctAnswers / (_correctAnswers + _incorrectAnswers) * 100) 
        : 0;
    
    // Determine cognitive control level
    String controlLevel;
    String explanation;
    
    if (accuracy >= 90) {
      controlLevel = 'Excellent';
      explanation = 'You have exceptional cognitive control and attention. You can effectively manage conflicting information.';
    } else if (accuracy >= 75) {
      controlLevel = 'Good';
      explanation = 'You have good cognitive control. You can generally manage conflicting information well.';
    } else if (accuracy >= 60) {
      controlLevel = 'Average';
      explanation = 'You have average cognitive control. You sometimes struggle with conflicting information.';
    } else {
      controlLevel = 'Needs Improvement';
      explanation = 'You may have difficulty managing conflicting information. This could indicate stress or fatigue affecting your cognitive control.';
    }
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Get.width * 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game over title
            Text(
              'Game Over',
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
                  // Total score
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
                  
                  // Statistics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Correct answers
                      Column(
                        children: [
                          Text(
                            'Correct',
                            style: TextStyle(
                              fontSize: Get.width * 0.035,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _correctAnswers.toString(),
                            style: TextStyle(
                              fontSize: Get.width * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      
                      // Incorrect answers
                      Column(
                        children: [
                          Text(
                            'Incorrect',
                            style: TextStyle(
                              fontSize: Get.width * 0.035,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _incorrectAnswers.toString(),
                            style: TextStyle(
                              fontSize: Get.width * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      
                      // Accuracy
                      Column(
                        children: [
                          Text(
                            'Accuracy',
                            style: TextStyle(
                              fontSize: Get.width * 0.035,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${accuracy.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: Get.width * 0.05,
                              fontWeight: FontWeight.bold,
                              color: ThemeConstants.mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Cognitive control level
                  Text(
                    'Cognitive Control',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    controlLevel,
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
                    ),
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