const UserModel = require("../models/user.model");
const bcrypt = require("bcrypt");

class UserService {
  static async registerUser(data) {
    try {
      const createUser = new UserModel(data);
      return await createUser.save();
    } catch (e) {
      throw e;
    }
  }
  static async findByCredentials(email, password) {
    try {
      const user = await UserModel.findOne({ email });
      if (user && (await bcrypt.compare(password, user.password))) {
        return user;
      }
      return null;
    } catch (e) {
      throw e;
    }
  }

  static getAllUsers = async () => {
    try {
      const users = await UserModel.find();
      return users;
    } catch (e) {
      throw e;
    }
  };
  
  static getUserById = async (userId) => {
    try {
      // Find user by ID
      const user = await UserModel.findById(userId);
      
      if (!user) {
        throw new Error('User not found');
      }
      
      // Return user without the password field
      const userObject = user.toObject();
      delete userObject.password;
      
      return userObject;
    } catch (e) {
      console.error('Error fetching user by ID:', e);
      throw e;
    }
  };

  static findUserByEmail = async (email) => {
    try {
      const user = await UserModel.findOne({ email });
      return user;
    } catch (e) {
      console.error('Error finding user by email:', e);
      throw e;
    }
  };
}

module.exports = UserService;
