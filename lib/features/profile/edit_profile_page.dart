// lib/features/profile/edit_profile_page.dart
// Edit Profile Page - Complete Profile Management UI

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile initialProfile;

  const EditProfilePage({
    Key? key,
    required this.initialProfile,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _repo = ProfileRepo(Supabase.instance.client);
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _handleController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  
  String? _avatarUrl;
  bool _isDiscoverable = true;
  bool _allowIncomingShares = true;
  bool _isLoading = false;
  bool _isCheckingHandle = false;
  String? _handleError;

  @override
  void initState() {
    super.initState();
    _handleController = TextEditingController(text: widget.initialProfile.handle);
    _displayNameController = TextEditingController(text: widget.initialProfile.displayName);
    _bioController = TextEditingController(text: widget.initialProfile.bio);
    _locationController = TextEditingController(text: widget.initialProfile.location);
    _avatarUrl = widget.initialProfile.avatarUrl;
    _isDiscoverable = widget.initialProfile.isDiscoverable;
    _allowIncomingShares = widget.initialProfile.allowIncomingShares;
    
    // Debounce handle checking
    _handleController.addListener(_checkHandleAvailability);
  }

  @override
  void dispose() {
    _handleController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _checkHandleAvailability() async {
    final handle = _handleController.text.trim().toLowerCase();
    if (handle.isEmpty || handle == widget.initialProfile.handle) {
      setState(() => _handleError = null);
      return;
    }

    setState(() => _isCheckingHandle = true);

    await Future.delayed(const Duration(milliseconds: 500)); // Debounce

    if (handle != _handleController.text.trim().toLowerCase()) {
      return; // User kept typing
    }

    final isAvailable = await _repo.isHandleAvailable(handle);
    
    if (mounted) {
      setState(() {
        _isCheckingHandle = false;
        _handleError = isAvailable ? null : 'Handle already taken';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '${Supabase.instance.client.auth.currentUser!.id}/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes);

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_handleError != null) return;

    setState(() => _isLoading = true);

    try {
      final success = await _repo.updateMyProfile(
        handle: _handleController.text.trim().toLowerCase(),
        displayName: _displayNameController.text.trim(),
        avatarUrl: _avatarUrl,
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        isDiscoverable: _isDiscoverable,
        allowIncomingShares: _allowIncomingShares,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D0D0F),
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 2,
                          ),
                        ),
                        child: _avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Color(0xFFD4AF37),
                                size: 40,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to change avatar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Display Name
                    TextFormField(
                      controller: _displayNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Display name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Handle
                    TextFormField(
                      controller: _handleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Handle',
                        prefixText: '@',
                        prefixStyle: const TextStyle(color: Color(0xFFD4AF37)),
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _isCheckingHandle
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                  ),
                                ),
                              )
                            : _handleError != null
                                ? const Icon(Icons.error, color: Colors.red)
                                : null,
                        errorText: _handleError,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Handle is required';
                        }
                        if (value.length < 3 || value.length > 20) {
                          return 'Handle must be 3-20 characters';
                        }
                        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                          return 'Only lowercase letters, numbers, and underscores';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      maxLength: 160,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    TextFormField(
                      controller: _locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Location (optional)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Privacy Toggles
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Privacy',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            value: _isDiscoverable,
                            onChanged: (value) => setState(() => _isDiscoverable = value),
                            title: const Text(
                              'Profile discoverable',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Allow others to find your profile',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            activeColor: const Color(0xFFD4AF37),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(color: Color(0xFF1A1A1A)),
                          SwitchListTile(
                            value: _allowIncomingShares,
                            onChanged: (value) => setState(() => _allowIncomingShares = value),
                            title: const Text(
                              'Allow receiving flows',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Others can share flows with you',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            activeColor: const Color(0xFFD4AF37),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

