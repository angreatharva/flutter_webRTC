const DoctorModel = require('../models/doctor.model');
const UserModel = require('../models/user.model');
const CallRequestModel = require('../models/callRequest.model');
const socketService = require('../services/socket.service');

// Get all active doctors (optimized for performance - NO IMAGE DATA)
const getActiveDoctors = async (req, res) => {
  try {
    // Highly optimized query - explicitly exclude image and password fields
    const activeDoctors = await DoctorModel.find(
      { isActive: true }, 
      {
        // Only select essential fields, completely exclude image and password
        doctorName: 1, 
        specialization: 1, 
        qualification: 1,
        email: 1,
        phone: 1,
        age: 1,
        gender: 1,
        isActive: 1
        // image and password fields are NOT selected (massive performance boost)
      }
    )
    .lean() // Return plain objects for better performance
    .sort({ doctorName: 1 }) // Consistent ordering
    .exec(); // Better performance

    res.status(200).json({
      success: true,
      message: 'Active doctors retrieved successfully',
      data: activeDoctors
    });
  } catch (error) {
    console.error('Error getting active doctors:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve active doctors',
      error: error.message
    });
  }
};

// Request a video call (for patients)
const requestVideoCall = async (req, res) => {
  try {
    const { patientId, doctorId, patientCallerId } = req.body;

    // Validate if doctor is active
    const doctor = await DoctorModel.findById(doctorId);
    if (!doctor) {
      return res.status(404).json({
        success: false,
        message: 'Doctor not found'
      });
    }

    if (!doctor.isActive) {
      return res.status(400).json({
        success: false,
        message: 'Doctor is not currently available for calls'
      });
    }

    // Check if there's already a pending request
    const existingRequest = await CallRequestModel.findOne({
      patientId,
      doctorId,
      status: 'pending'
    });

    if (existingRequest) {
      return res.status(400).json({
        success: false,
        message: 'You already have a pending request with this doctor'
      });
    }

    // Create new call request
    const callRequest = new CallRequestModel({
      patientId,
      doctorId,
      patientCallerId
    });

    await callRequest.save();
    
    // Emit socket event for new call request
    socketService.emitNewCallRequest(doctorId, patientId, callRequest._id.toString());

    res.status(201).json({
      success: true,
      message: 'Video call request sent successfully',
      data: callRequest
    });
  } catch (error) {
    console.error('Error requesting video call:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to request video call',
      error: error.message
    });
  }
};

// Get pending call requests (for doctors)
const getPendingCallRequests = async (req, res) => {
  try {
    const { doctorId } = req.params;

    const pendingRequests = await CallRequestModel.find({
      doctorId,
      status: 'pending'
    }).populate('patientId', 'userName age gender');

    res.status(200).json({
      success: true,
      message: 'Pending call requests retrieved successfully',
      data: pendingRequests
    });
  } catch (error) {
    console.error('Error getting pending call requests:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve pending call requests',
      error: error.message
    });
  }
};

// Update call request status (for doctors)
const updateCallRequestStatus = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { status } = req.body;

    if (!['accepted', 'rejected', 'completed'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status value'
      });
    }

    const callRequest = await CallRequestModel.findById(requestId);
    
    if (!callRequest) {
      return res.status(404).json({
        success: false,
        message: 'Call request not found'
      });
    }

    callRequest.status = status;
    
    if (status === 'completed') {
      callRequest.completedAt = new Date();
    }

    await callRequest.save();
    
    // Emit socket event for call request status update
    socketService.emitCallRequestStatusUpdate(
      callRequest.doctorId.toString(),
      callRequest.patientId.toString(), 
      requestId,
      status
    );

    res.status(200).json({
      success: true,
      message: `Call request ${status} successfully`,
      data: callRequest
    });
  } catch (error) {
    console.error('Error updating call request status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update call request status',
      error: error.message
    });
  }
};

module.exports = {
  getActiveDoctors,
  requestVideoCall,
  getPendingCallRequests,
  updateCallRequestStatus
}; 