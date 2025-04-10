// controllers/transcription.controller.js
const Transcription = require('../models/transcription.model');

// Add a new transcription segment
exports.addTranscription = async (req, res) => {
  try {
    const { callId, speakerId, role, text } = req.body;
    
    if (!callId || !speakerId || !role || !text) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields' 
      });
    }

    const newTranscription = new Transcription({
      callId,
      speakerId,
      role,
      text
    });

    const savedTranscription = await newTranscription.save();
    
    return res.status(201).json({
      success: true,
      data: savedTranscription
    });
  } catch (error) {
    console.error('Error adding transcription:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

// Get transcriptions for a call
exports.getTranscriptions = async (req, res) => {
  try {
    const { callId } = req.params;
    
    if (!callId) {
      return res.status(400).json({
        success: false,
        message: 'Call ID is required'
      });
    }

    const transcriptions = await Transcription.find({ callId }).sort('timestamp');
    
    return res.status(200).json({
      success: true,
      count: transcriptions.length,
      data: transcriptions
    });
  } catch (error) {
    console.error('Error fetching transcriptions:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};