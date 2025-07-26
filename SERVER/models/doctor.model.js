const mongoose = require("../config/db");
const bcrypt = require("bcrypt");

const { Schema } = mongoose;

/**
 * @swagger
 * components:
 *   schemas:
 *     Doctor:
 *       type: object
 *       required:
 *         - doctorName
 *         - phone
 *         - age
 *         - gender
 *         - email
 *         - qualification
 *         - specialization
 *         - licenseNumber
 *         - image
 *         - password
 *       properties:
 *         _id:
 *           type: string
 *           description: Auto-generated MongoDB ObjectId
 *         doctorName:
 *           type: string
 *           description: Doctor's full name
 *         phone:
 *           type: string
 *           description: Doctor's phone number
 *         age:
 *           type: integer
 *           description: Doctor's age
 *         gender:
 *           type: string
 *           description: Doctor's gender
 *           enum: [male, female, other]
 *         email:
 *           type: string
 *           format: email
 *           description: Doctor's email address (unique)
 *         qualification:
 *           type: string
 *           description: Doctor's medical qualification
 *         specialization:
 *           type: string
 *           description: Doctor's medical specialization
 *         licenseNumber:
 *           type: string
 *           description: Doctor's medical license number (unique)
 *         image:
 *           type: string
 *           format: binary
 *           description: Doctor's profile image
 *         isActive:
 *           type: boolean
 *           description: Doctor's availability status
 *           default: false
 *         password:
 *           type: string
 *           format: password
 *           description: Doctor's hashed password
 *       example:
 *         _id: 60d0fe4f5311236168a109cb
 *         doctorName: Dr. Jane Smith
 *         phone: "9876543210"
 *         age: 40
 *         gender: female
 *         email: dr.jane.smith@example.com
 *         qualification: MBBS, MD
 *         specialization: Cardiology
 *         licenseNumber: MED12345
 *         isActive: true
 */
const doctorSchema = new Schema({
  doctorName: {
    type: String,
    required: true,
    trim: true,
    validate: {
      validator: function(v) {
        return /^[a-zA-Z\s]+$/.test(v);
      },
      message: 'Doctor name should contain only letters and spaces'
    }
  },
  phone: {
    type: String,
    required: true,
    validate: {
      validator: function(v) {
        return /^\d{10}$/.test(v);
      },
      message: 'Phone number must be exactly 10 digits'
    }
  },
  age: {
    type: Number,
    required: true,
    min: [18, 'Age must be at least 18'],
    max: [100, 'Age must be less than 100']
  },
  gender: {
    type: String,
    required: true,
    enum: ['Male', 'Female', 'Other']
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    validate: {
      validator: function(v) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
      },
      message: 'Please enter a valid email address'
    }
  },
  qualification: {
    type: String,
    required: true,
    trim: true
  },
  specialization: {
    type: String,
    required: true,
    trim: true
  },
  licenseNumber: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    uppercase: true
  },
  image: {
    type: String, // Store as base64 string or file path
    required: false,
  },
  isActive: {
    required: true,
    default: false,
    type: Boolean,
  },
  password: {
    type: String,
    required: true,
    minlength: [6, 'Password must be at least 6 characters long']
  },
});

// Pre-save hook to hash the password
doctorSchema.pre("save", async function (next) {
  if (this.isModified("password")) {
    try {
      const salt = await bcrypt.genSalt(10);
      this.password = await bcrypt.hash(this.password, salt);
    } catch (err) {
      return next(err);
    }
  }
  next();
});

// Method to compare passwords
doctorSchema.methods.comparePassword = async function (candidatePassword) {
  try {
    return await bcrypt.compare(candidatePassword, this.password);
  } catch (err) {
    throw err;
  }
};

// Method to toggle active status
doctorSchema.methods.toggleActive = async function() {
  try {
    this.isActive = !this.isActive;
    return await this.save();
  } catch (err) {
    throw err;
  }
};

const DoctorModel = mongoose.model("doctorData", doctorSchema, "doctorData");
module.exports = DoctorModel;
