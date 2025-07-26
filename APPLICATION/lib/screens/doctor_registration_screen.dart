import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../utils/theme_constants.dart';


class DoctorRegistrationScreen extends StatefulWidget {
  const DoctorRegistrationScreen({Key? key}) : super(key: key);

  @override
  _DoctorRegistrationScreenState createState() => _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _specializationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _imageFile;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70, // Compress to 70% quality
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Helper function to compress image to base64 with size limit
  Future<String?> _compressImageToBase64(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // If image is larger than 5MB, show error
      if (imageBytes.length > 5 * 1024 * 1024) {
        Get.snackbar(
          'Image Too Large',
          'Please select an image smaller than 5MB',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }
      
      return base64Encode(imageBytes);
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConstants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: Get.width * 0.06),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar with back button
                  SizedBox(height: Get.height * 0.02),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: ThemeConstants.mainColor,
                          size: Get.width * 0.05,
                        ),
                        onPressed: () => Get.back(),
                      ),
                      SizedBox(width: Get.width * 0.02),
                      Text(
                        'Doctor Registration',
                        style: TextStyle(
                          color: ThemeConstants.mainColor,
                          fontSize: Get.width * 0.055,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: Get.height * 0.02),
                  
                  // Logo and App Name
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: Get.width * 0.25,
                            height: Get.width * 0.25,
                            decoration: BoxDecoration(
                              color: _imageFile == null
                                ? ThemeConstants.mainColor
                                : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                              image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            ),
                            child: _imageFile == null
                              ? Icon(
                                  Icons.camera_alt,
                                  size: Get.width * 0.12,
                                  color: Colors.white,
                                )
                              : null,
                          ),
                        ),
                        SizedBox(height: Get.height * 0.02),
                        Text(
                          'NeuraLife',
                          style: TextStyle(
                            color: ThemeConstants.mainColor,
                            fontSize: Get.width * 0.07,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: Get.height * 0.01),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Get.width * 0.04,
                            vertical: Get.height * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeConstants.mainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(Get.width * 0.05),
                          ),
                          child: Text(
                            'Your Health, Our Priority',
                            style: TextStyle(
                              color: ThemeConstants.mainColor,
                              fontSize: Get.width * 0.04,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: Get.height * 0.04),
                  
                  // Registration Form
                  Text(
                    'Create Doctor Account',
                    style: TextStyle(
                      color: ThemeConstants.mainColor,
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: Get.height * 0.01),
                  Text(
                    'Fill in your details to register as a healthcare provider',
                    style: TextStyle(
                      fontSize: Get.width * 0.04,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: Get.height * 0.03),
                  
                  // Full Name Field
                  _buildTextField(
                    controller: _nameController,
                    icon: Icons.person_outline,
                    hint: 'Full Name',
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter your name';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                        return 'Name should contain only letters and spaces';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    hint: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Phone Field
                  _buildTextField(
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    hint: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    numbersOnly: true,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return 'Please enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Age Field
                  _buildTextField(
                    controller: _ageController,
                    icon: Icons.calendar_today_outlined,
                    hint: 'Age',
                    keyboardType: TextInputType.number,
                    numbersOnly: true,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please enter your age';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 0 || age > 120) {
                        return 'Please enter a valid age';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Gender Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Get.width * 0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        hintText: 'Gender',
                        prefixIcon: Icon(
                          Icons.people_outline,
                          color: ThemeConstants.mainColor,
                          size: Get.width * 0.06,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Get.width * 0.04),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Get.width * 0.04,
                          vertical: Get.height * 0.02,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: TextStyle(
                        fontSize: Get.width * 0.04,
                        color: Colors.black87,
                      ),
                      dropdownColor: Colors.white,
                      items: ['Male', 'Female', 'Other']
                          .map((gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Qualification Field
                  _buildTextField(
                    controller: _qualificationController,
                    icon: Icons.school_outlined,
                    hint: 'Qualification',
                    validator: (value) => value!.isEmpty ? 'Please enter your qualification' : null,
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Specialization Field
                  _buildTextField(
                    controller: _specializationController,
                    icon: Icons.medical_services_outlined,
                    hint: 'Specialization',
                    validator: (value) => value!.isEmpty ? 'Please enter your specialization' : null,
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // License Field
                  _buildTextField(
                    controller: _licenseController,
                    icon: Icons.badge_outlined,
                    hint: 'License Number',
                    validator: (value) => value!.isEmpty ? 'Please enter your license number' : null,
                  ),
                  SizedBox(height: Get.height * 0.02),
                  
                  // Password Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Get.width * 0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: ThemeConstants.mainColor,
                          size: Get.width * 0.06,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: ThemeConstants.mainColor,
                            size: Get.width * 0.06,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Get.width * 0.04),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Get.width * 0.04,
                          vertical: Get.height * 0.02,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: Get.width * 0.04),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  SizedBox(height: Get.height * 0.04),
                  
                  // Register Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConstants.mainColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: Get.height * 0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Get.width * 0.04),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: Get.width * 0.06,
                            width: Get.width * 0.06,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Register',
                            style: TextStyle(
                              fontSize: Get.width * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  
                  SizedBox(height: Get.height * 0.02),
                  
                  // Login Link
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Already have an account? Login',
                      style: TextStyle(
                        color: ThemeConstants.mainColor,
                        fontSize: Get.width * 0.04,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: Get.height * 0.02),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
    int? maxLength,
    bool numbersOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Get.width * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConstants.mainColor,
            size: Get.width * 0.06,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Get.width * 0.04),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: Get.width * 0.04,
            vertical: Get.height * 0.02,
          ),
          filled: true,
          fillColor: Colors.white,
          counterText: '', // Hide the character counter
        ),
        keyboardType: keyboardType,
        style: TextStyle(fontSize: Get.width * 0.04),
        validator: validator,
        maxLength: maxLength,
        inputFormatters: numbersOnly ? [
          FilteringTextInputFormatter.digitsOnly,
        ] : null,
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      Get.snackbar(
        'Error',
        'Please select a profile image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? base64Image;
      if (_imageFile != null) {
        base64Image = await _compressImageToBase64(_imageFile!);
        if (base64Image == null) {
          setState(() => _isLoading = false);
          return; // Error already shown in _compressImageToBase64
        }
      }

      final doctorData = {
        'doctorName': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'age': int.parse(_ageController.text),
        'gender': _selectedGender,
        'qualification': _qualificationController.text,
        'specialization': _specializationController.text,
        'licenseNumber': _licenseController.text,
        'password': _passwordController.text,
        'image': base64Image,
      };

      final response = await AuthService.instance.registerDoctor(doctorData);

      if (response['success']) {
        Get.back();
        Get.snackbar(
          'Success',
          'Registration successful! Please login.',
          backgroundColor: ThemeConstants.secondaryColor,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }
      if (errorMessage.contains('Failed to register doctor:')) {
        errorMessage = errorMessage.replaceFirst('Failed to register doctor: ', '');
      }
      
      // Handle specific error cases
      if (errorMessage.contains('413') || errorMessage.contains('too large') || errorMessage.contains('PAYLOAD_TOO_LARGE')) {
        errorMessage = 'Image file is too large. Please select a smaller image (under 5MB).';
      }
      
      Get.snackbar(
        'Registration Failed',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 4),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _licenseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 