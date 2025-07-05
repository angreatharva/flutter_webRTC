import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/theme_constants.dart';

class BalloonRiskGame extends StatefulWidget {
  const BalloonRiskGame({Key? key}) : super(key: key);

  @override
  State<BalloonRiskGame> createState() => _BalloonRiskGameState();
}

class _BalloonRiskGameState extends State<BalloonRiskGame> {
  // Game state variables
  double _balloonSize = 100.0;
  int _currentPoints = 0;
  int _bankedPoints = 0;
  int _totalPoints = 0;
  int _poppedBalloons = 0;
  int _successfulBalloons = 0;
  bool _isPopped = false;
  bool _gameOver = false;
  int _remainingBalloons = 10;
  
  // Risk variables
  double _basePopProbability = 0.05; // Starting probability
  double _currentPopProbability = 0.05;
  double _popProbabilityIncrease = 0.05; // Increase per tap
  
  // Points variables
  int _pointsPerTap = 10;
  double _pointsMultiplier = 1.0;
  
  // Animation variables
  final Duration _animationDuration = const Duration(milliseconds: 150);
  
  // Random generator
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    _resetBalloon();
  }
  
  void _inflateBalloon() {
    if (_isPopped || _gameOver) return;
    
    // Check if balloon pops
    if (_random.nextDouble() < _currentPopProbability) {
      _popBalloon();
      return;
    }
    
    // Inflate balloon and add points
    setState(() {
      _balloonSize += 15.0;
      _currentPoints += _pointsPerTap;
      _currentPopProbability += _popProbabilityIncrease;
      _pointsMultiplier += 0.1;
    });
  }
  
  void _popBalloon() {
    setState(() {
      _isPopped = true;
      _currentPoints = 0;
      _poppedBalloons++;
      _remainingBalloons--;
    });
    
    // Check if game over
    if (_remainingBalloons <= 0) {
      _endGame();
      return;
    }
    
    // Reset balloon after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _resetBalloon();
      }
    });
  }
  
  void _bankPoints() {
    if (_isPopped || _gameOver || _currentPoints == 0) return;
    
    setState(() {
      _bankedPoints += _currentPoints;
      _totalPoints += _currentPoints;
      _currentPoints = 0;
      _successfulBalloons++;
      _remainingBalloons--;
    });
    
    // Check if game over
    if (_remainingBalloons <= 0) {
      _endGame();
      return;
    }
    
    // Reset balloon
    _resetBalloon();
  }
  
  void _resetBalloon() {
    setState(() {
      _balloonSize = 100.0;
      _isPopped = false;
      _currentPopProbability = _basePopProbability;
      _pointsMultiplier = 1.0;
    });
  }
  
  void _endGame() {
    setState(() {
      _gameOver = true;
      _totalPoints = _bankedPoints;
    });
  }
  
  void _restartGame() {
    setState(() {
      _balloonSize = 100.0;
      _currentPoints = 0;
      _bankedPoints = 0;
      _totalPoints = 0;
      _poppedBalloons = 0;
      _successfulBalloons = 0;
      _isPopped = false;
      _gameOver = false;
      _remainingBalloons = 10;
      _currentPopProbability = _basePopProbability;
      _pointsMultiplier = 1.0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConstants.backgroundColor,
        elevation: 0,
        title: Text(
          'Balloon Risk Game',
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
    return Column(
      children: [
        // Score and balloon counter
        Padding(
          padding: EdgeInsets.all(Get.width * 0.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current points
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Points',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _currentPoints.toString(),
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
                    ),
                  ),
                ],
              ),
              
              // Banked points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Banked Points',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _bankedPoints.toString(),
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
        ),
        
        // Remaining balloons
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Get.width * 0.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Remaining Balloons: ',
                style: TextStyle(
                  fontSize: Get.width * 0.04,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                _remainingBalloons.toString(),
                style: TextStyle(
                  fontSize: Get.width * 0.04,
                  fontWeight: FontWeight.bold,
                  color: ThemeConstants.mainColor,
                ),
              ),
            ],
          ),
        ),
        
        // Risk indicator
        Padding(
          padding: EdgeInsets.all(Get.width * 0.04),
          child: Column(
            children: [
              Text(
                'Pop Risk',
                style: TextStyle(
                  fontSize: Get.width * 0.035,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: Get.height * 0.01),
              LinearProgressIndicator(
                value: _currentPopProbability,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _currentPopProbability < 0.3
                    ? Colors.green
                    : _currentPopProbability < 0.6
                      ? Colors.orange
                      : Colors.red,
                ),
                minHeight: Get.height * 0.015,
                borderRadius: BorderRadius.circular(Get.width * 0.01),
              ),
            ],
          ),
        ),
        
        // Balloon
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _inflateBalloon,
              child: AnimatedContainer(
                duration: _animationDuration,
                width: _isPopped ? 20 : _balloonSize,
                height: _isPopped ? 20 : _balloonSize * 1.2,
                decoration: BoxDecoration(
                  color: _isPopped ? Colors.transparent : ThemeConstants.mainColor,
                  borderRadius: BorderRadius.circular(_balloonSize / 2),
                ),
                child: _isPopped
                  ? Icon(
                      Icons.bubble_chart,
                      color: Colors.red,
                      size: Get.width * 0.2,
                    )
                  : null,
              ),
            ),
          ),
        ),
        
        // Instructions
        Padding(
          padding: EdgeInsets.all(Get.width * 0.04),
          child: Text(
            _isPopped
              ? 'Balloon popped! Starting new balloon...'
              : 'Tap the balloon to inflate it and earn points. The bigger it gets, the more likely it will pop!',
            style: TextStyle(
              fontSize: Get.width * 0.035,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Bank button
        Padding(
          padding: EdgeInsets.all(Get.width * 0.04),
          child: ElevatedButton(
            onPressed: _currentPoints > 0 && !_isPopped ? _bankPoints : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConstants.accentColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: Get.width * 0.08,
                vertical: Get.height * 0.02,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Get.width * 0.05),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              'Bank Points',
              style: TextStyle(
                fontSize: Get.width * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildGameOverScreen() {
    // Calculate risk-taking score (0-100)
    int riskScore = ((_poppedBalloons / (_poppedBalloons + _successfulBalloons)) * 100).round();
    
    // Determine risk profile
    String riskProfile;
    if (riskScore < 30) {
      riskProfile = 'Conservative';
    } else if (riskScore < 70) {
      riskProfile = 'Balanced';
    } else {
      riskProfile = 'Risk-Taker';
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
                    'Total Score',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _totalPoints.toString(),
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
                      // Successful balloons
                      Column(
                        children: [
                          Text(
                            'Banked',
                            style: TextStyle(
                              fontSize: Get.width * 0.035,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _successfulBalloons.toString(),
                            style: TextStyle(
                              fontSize: Get.width * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      
                      // Popped balloons
                      Column(
                        children: [
                          Text(
                            'Popped',
                            style: TextStyle(
                              fontSize: Get.width * 0.035,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _poppedBalloons.toString(),
                            style: TextStyle(
                              fontSize: Get.width * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Risk profile
                  Text(
                    'Risk Profile',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    riskProfile,
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.mainColor,
                    ),
                  ),
                  SizedBox(height: Get.height * 0.01),
                  
                  // Risk score
                  LinearProgressIndicator(
                    value: riskScore / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      riskScore < 30
                        ? Colors.green
                        : riskScore < 70
                          ? Colors.orange
                          : Colors.red,
                    ),
                    minHeight: Get.height * 0.015,
                    borderRadius: BorderRadius.circular(Get.width * 0.01),
                  ),
                  SizedBox(height: Get.height * 0.01),
                  
                  // Risk explanation
                  Text(
                    _getRiskExplanation(riskProfile),
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
  
  String _getRiskExplanation(String riskProfile) {
    switch (riskProfile) {
      case 'Conservative':
        return 'You tend to avoid risks, preferring safety over potential rewards. This can be associated with anxiety or caution.';
      case 'Balanced':
        return 'You balance risks and rewards well, showing good decision-making skills and emotional regulation.';
      case 'Risk-Taker':
        return 'You embrace risks, seeking higher rewards despite potential losses. This can be associated with impulsivity or sensation-seeking.';
      default:
        return '';
    }
  }
}