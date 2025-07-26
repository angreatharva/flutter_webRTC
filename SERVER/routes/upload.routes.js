const express = require('express');
const router = express.Router();
const upload = require('../middleware/upload.middleware');
const Doctor = require('../models/doctor.model');
const path = require('path');

/**
 * @swagger
 * /api/upload/doctor-registration:
 *   post:
 *     summary: Register a new doctor with image upload
 *     tags: [Upload]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - doctorName
 *               - email
 *               - phone
 *               - age
 *               - gender
 *               - qualification
 *               - specialization
 *               - licenseNumber
 *               - password
 *             properties:
 *               doctorName:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               phone:
 *                 type: string
 *               age:
 *                 type: integer
 *               gender:
 *                 type: string
 *               qualification:
 *                 type: string
 *               specialization:
 *                 type: string
 *               licenseNumber:
 *                 type: string
 *               password:
 *                 type: string
 *                 format: password
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Doctor registered successfully
 *       400:
 *         description: Invalid input or doctor already exists
 *       500:
 *         description: Server error
 */
router.post('/doctor-registration', (req, res) => {
  upload(req, res, async (err) => {
    if (err) {
      return res.status(400).json({
        success: false,
        message: err.message
      });
    }

    try {
      const {
        doctorName,
        email,
        phone,
        age,
        gender,
        qualification,
        specialization,
        licenseNumber,
        password
      } = req.body;

      // Validate required fields
      if (!doctorName || !email || !phone || !age || !gender || 
          !qualification || !specialization || !licenseNumber || !password) {
        return res.status(400).json({
          success: false,
          message: "All fields are required.",
        });
      }

      // Check if doctor already exists
      const existingDoctor = await Doctor.findOne({ 
        $or: [{ email }, { licenseNumber }] 
      });
      
      if (existingDoctor) {
        return res.status(400).json({
          success: false,
          message: "Doctor with this email or license number already exists.",
        });
      }

      // Prepare doctor data
      const doctorData = {
        doctorName,
        email,
        phone,
        age: parseInt(age),
        gender,
        qualification,
        specialization,
        licenseNumber,
        password,
        image: req.file ? req.file.filename : null, // Store filename
        isActive: false
      };

      const doctor = new Doctor(doctorData);
      const savedDoctor = await doctor.save();

      // Remove password from response
      const doctorResponse = savedDoctor.toObject();
      delete doctorResponse.password;

      res.status(201).json({
        success: true,
        data: doctorResponse,
        message: "Doctor registered successfully!",
      });
    } catch (error) {
      console.error("Error registering doctor:", error);
      
      if (error.code === 11000) {
        const field = Object.keys(error.keyPattern)[0];
        return res.status(400).json({
          success: false,
          message: `Doctor with this ${field} already exists.`,
        });
      }
      
      res.status(500).json({
        success: false,
        message: "Error registering doctor: " + error.message,
      });
    }
  });
});

/**
 * @swagger
 * /api/upload/doctor-image/{filename}:
 *   get:
 *     summary: Get doctor profile image
 *     tags: [Upload]
 *     parameters:
 *       - in: path
 *         name: filename
 *         required: true
 *         schema:
 *           type: string
 *         description: Image filename
 *     responses:
 *       200:
 *         description: Image file
 *         content:
 *           image/*:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: Image not found
 */
router.get('/doctor-image/:filename', (req, res) => {
  const filename = req.params.filename;
  const imagePath = path.join(__dirname, '../uploads', filename);
  
  res.sendFile(imagePath, (err) => {
    if (err) {
      res.status(404).json({
        success: false,
        message: 'Image not found'
      });
    }
  });
});

module.exports = router;