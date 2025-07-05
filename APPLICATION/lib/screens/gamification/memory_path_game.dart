import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/theme_constants.dart';

class MemoryPathGame extends StatefulWidget {
  const MemoryPathGame({Key? key}) : super(key: key);

  @override
  State<MemoryPathGame> createState() => _MemoryPathGameState();
}

class _MemoryPathGameState extends State<MemoryPathGame> {
  // Game state variables
  int _score = 0;
  int _level = 1;
  bool _isShowingPattern = false;
  bool _isPlayerTurn = false;
  bool _gameOver = false;
  
  // Pattern variables
  final List<int> _pattern = [];
  final List<int> _playerPattern = [];
  final int _maxLevel = 20; // Maximum level to reach
  
  // Color buttons
  final List<Color> _buttonColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];
  
  // Highlighted button state
  int? _highlightedButton;
  
  // Random generator
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    _startGame();
  }
  
  void _startGame() {
    setState(() {
      _score = 0;
      _level = 1;
      _pattern.clear();
      _playerPattern.clear();
      _isShowingPattern = false;
      _isPlayerTurn = false;
      _gameOver = false;
    });
    
    _addToPattern();
    _showPattern();
  }
  
  void _addToPattern() {
    // Add a random color to the pattern
    _pattern.add(_random.nextInt(_buttonColors.length));
  }
  
  void _showPattern() {
    setState(() {
      _isShowingPattern = true;
      _isPlayerTurn = false;
      _playerPattern.clear();
      _highlightedButton = null; // Ensure no button is highlighted at start
    });
    
    // Show the pattern with delays between each color
    int index = 0;
    
    // Use a longer initial delay to prepare the user
    Future.delayed(const Duration(milliseconds: 1000), () {
      // Create a timer that shows each pattern element
      Timer.periodic(const Duration(milliseconds: 1200), (timer) {
        if (index < _pattern.length) {
          // Highlight the button
          setState(() {
            _highlightedButton = _pattern[index];
          });
          
          // Unhighlight after a delay
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _highlightedButton = null;
              });
            }
          });
          
          index++;
        } else {
          // Pattern finished, player's turn
          timer.cancel();
          if (mounted) {
            setState(() {
              _isShowingPattern = false;
              _isPlayerTurn = true;
            });
          }
        }
      });
    });
  }
  
  void _onButtonPressed(int colorIndex) {
    if (!_isPlayerTurn || _isShowingPattern || _gameOver) return;
    
    // Highlight the pressed button briefly
    setState(() {
      _highlightedButton = colorIndex;
    });
    
    // Play feedback animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _highlightedButton = null;
        });
      }
    });
    
    // Add to player pattern
    _playerPattern.add(colorIndex);
    
    // Check if the player's input matches the pattern so far
    if (_playerPattern.last != _pattern[_playerPattern.length - 1]) {
      // Wrong input, show error feedback
      _showErrorFeedback();
      
      // End game after a short delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _endGame();
        }
      });
      return;
    }
    
    // Check if the player completed the current pattern
    if (_playerPattern.length == _pattern.length) {
      // Pattern completed successfully, show success feedback
      _showSuccessFeedback();
      
      // Update score and level
      setState(() {
        _score += _level * 10; // Score based on level
        _level++;
      });
      
      if (_level > _maxLevel) {
        // Player reached the maximum level, game completed
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _completeGame();
          }
        });
        return;
      }
      
      // Add a new color to the pattern and show it again after a delay
      _addToPattern();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _showPattern();
        }
      });
    }
  }
  
  void _showErrorFeedback() {
    // Flash all buttons red briefly to indicate error
    setState(() {
      _isPlayerTurn = false; // Prevent further input during animation
    });
    
    // Flash effect
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          setState(() {
            _highlightedButton = i % 2 == 0 ? -999 : null; // Special value to trigger error state
          });
        }
      });
    }
  }
  
  void _showSuccessFeedback() {
    // Show success animation
    setState(() {
      _isPlayerTurn = false; // Prevent further input during animation
    });
    
    // Success effect - briefly highlight all buttons in sequence
    for (int i = 0; i < _buttonColors.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          setState(() {
            _highlightedButton = i;
          });
          
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _highlightedButton = null;
              });
            }
          });
        }
      });
    }
  }
  
  void _endGame() {
    setState(() {
      _gameOver = true;
      _isPlayerTurn = false;
    });
  }
  
  void _completeGame() {
    setState(() {
      _gameOver = true;
      _isPlayerTurn = false;
    });
  }
  
  void _restartGame() {
    _startGame();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConstants.backgroundColor,
        elevation: 0,
        title: Text(
          'Memory Path Game',
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
          // Score and level row
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
              
              // Level
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Level',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _level.toString(),
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
          
          // Status text
          Padding(
            padding: EdgeInsets.symmetric(vertical: Get.height * 0.03),
            child: Text(
              _isShowingPattern
                ? 'Watch the pattern...'
                : _isPlayerTurn
                  ? 'Your turn! Repeat the pattern'
                  : 'Get ready...',
              style: TextStyle(
                fontSize: Get.width * 0.045,
                fontWeight: FontWeight.bold,
                color: ThemeConstants.mainColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Pattern length indicator
          Padding(
            padding: EdgeInsets.only(bottom: Get.height * 0.02),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Pattern: ',
                  style: TextStyle(
                    fontSize: Get.width * 0.04,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '${_playerPattern.length}/${_pattern.length}',
                  style: TextStyle(
                    fontSize: Get.width * 0.04,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.mainColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Color buttons grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              mainAxisSpacing: Get.width * 0.04,
              crossAxisSpacing: Get.width * 0.04,
              padding: EdgeInsets.all(Get.width * 0.04),
              children: List.generate(_buttonColors.length, (index) {
                return GestureDetector(
                  onTap: () => _onButtonPressed(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _highlightedButton == -999 // Error state
                        ? Colors.red
                        : _highlightedButton == index
                          ? _buttonColors[index]
                          : _buttonColors[index].withOpacity(0.5),
                      borderRadius: BorderRadius.circular(Get.width * 0.04),
                      boxShadow: [
                        BoxShadow(
                          color: _highlightedButton == -999 // Error state
                            ? Colors.red.withOpacity(0.7)
                            : _highlightedButton == index
                              ? _buttonColors[index].withOpacity(0.7)
                              : Colors.black.withOpacity(0.2),
                          spreadRadius: _highlightedButton == -999 || _highlightedButton == index ? 3 : 1,
                          blurRadius: _highlightedButton == -999 || _highlightedButton == index ? 10 : 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _highlightedButton == -999 // Error state
                        ? Icon(
                            Icons.close,
                            color: Colors.white,
                            size: Get.width * 0.1,
                          )
                        : _highlightedButton == index
                          ? Icon(
                              Icons.lightbulb,
                              color: Colors.white,
                              size: Get.width * 0.1,
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Instructions
          Padding(
            padding: EdgeInsets.all(Get.width * 0.04),
            child: Text(
              'Remember the pattern and repeat it by tapping the colors in the same order.',
              style: TextStyle(
                fontSize: Get.width * 0.035,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameOverScreen() {
    // Calculate memory score (0-100)
    int memoryScore = ((_level - 1) / _maxLevel * 100).round();
    
    // Determine memory assessment
    String memoryAssessment;
    String explanation;
    
    if (memoryScore >= 80) {
      memoryAssessment = 'Excellent';
      explanation = 'You have exceptional short-term memory and attention to detail. You can effectively remember and reproduce complex patterns.';
    } else if (memoryScore >= 60) {
      memoryAssessment = 'Good';
      explanation = 'You have good short-term memory. You can remember and reproduce moderately complex patterns.';
    } else if (memoryScore >= 40) {
      memoryAssessment = 'Average';
      explanation = 'You have average short-term memory. You can remember simple patterns but may struggle with more complex ones.';
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
              _level > _maxLevel ? 'Game Completed!' : 'Game Over',
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
                  
                  // Level reached
                  Text(
                    'Level Reached',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    (_level - 1).toString(),
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
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