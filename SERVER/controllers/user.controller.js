const UserService = require("../services/user.services");

exports.registerUser = async (req, res) => {
  try {
    const { userName, email, phone, age, gender, password } = req.body;

    // Validate required fields
    if (!userName || !email || !phone || !age || !gender || !password) {
      return res.status(400).json({
        registered: false,
        response: "All fields are required.",
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        registered: false,
        response: "Please enter a valid email address.",
      });
    }

    // Validate phone number (10 digits)
    const phoneRegex = /^\d{10}$/;
    if (!phoneRegex.test(phone)) {
      return res.status(400).json({
        registered: false,
        response: "Please enter a valid 10-digit phone number.",
      });
    }

    // Validate age
    const ageNum = parseInt(age);
    if (isNaN(ageNum) || ageNum < 0 || ageNum > 120) {
      return res.status(400).json({
        registered: false,
        response: "Please enter a valid age between 0 and 120.",
      });
    }

    // Validate name (should contain only letters and spaces)
    const nameRegex = /^[a-zA-Z\s]+$/;
    if (!nameRegex.test(userName)) {
      return res.status(400).json({
        registered: false,
        response: "Name should contain only letters and spaces.",
      });
    }

    // Check if user already exists
    const existingUser = await UserService.findUserByEmail(email);
    if (existingUser) {
      return res.status(400).json({
        registered: false,
        response: "User with this email already exists.",
      });
    }

    const userData = {
      userName,
      email,
      phone,
      age: ageNum,
      gender,
      password
    };

    const successRes = await UserService.registerUser(userData);
    
    // Remove password from response
    const userResponse = successRes.toObject();
    delete userResponse.password;
    
    res.status(201).json({
      registered: true,
      data: userResponse,
      response: "Registered User Successfully!",
    });
  } catch (e) {
    console.error("Error registering User:", e);
    
    if (e.code === 11000) {
      // Duplicate key error
      return res.status(400).json({
        registered: false,
        response: "User with this email already exists.",
      });
    }
    
    res.status(500).json({
      registered: false,
      response: "Error registering User: " + e.message,
    });
  }
};

exports.getRegisteredUsers = async (req, res) => {
  try {
    const users = await UserService.getAllUsers();
    res.status(200).json({
      success: true,
      data: users,
      response: "Fetched registered users successfully!",
    });
  } catch (e) {
    console.error("Error fetching registered users:", e);
    res.status(500).json({
      success: false,
      response: "Error fetching registered users",
    });
  }
};

exports.getUserById = async (req, res) => {
  try {
    const userId = req.params.id;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        response: "User ID is required"
      });
    }
    
    const user = await UserService.getUserById(userId);
    
    res.status(200).json({
      success: true,
      data: user,
      response: "User details fetched successfully"
    });
  } catch (e) {
    console.error("Error fetching user details:", e);
    
    // Check if it's a "User not found" error
    if (e.message === 'User not found') {
      return res.status(404).json({
        success: false,
        response: "User not found"
      });
    }
    
    // For other errors
    res.status(500).json({
      success: false,
      response: "Error fetching user details"
    });
  }
};
