import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../services/study_analyzer_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String userId; 

  const AddTaskScreen({super.key, required this.userId});

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  
  String _selectedTaskType = 'Assignment';
  DateTime? _selectedDate;
  bool _isLoading = false;

  final List<String> _taskTypes = ['Assignment', 'Project', 'Exam'];

  Future<void> _pickDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitTask() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      setState(() => _isLoading = true);

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      bool success = await StudyAnalyzerService.addTask(
        userId: widget.userId,
        title: _titleController.text.trim(),
        courseName: _courseController.text.trim(),
        taskType: _selectedTaskType,
        dueDate: formattedDate,
        estimatedHours: int.parse(_hoursController.text.trim()),
      );

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add task.'), backgroundColor: Colors.red),
        );
      }
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date.'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title (e.g. Midterm)'),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _courseController,
                decoration: const InputDecoration(labelText: 'Course Name (e.g. CSE470)'),
                validator: (value) => value!.isEmpty ? 'Please enter a course' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedTaskType,
                decoration: const InputDecoration(labelText: 'Task Type'),
                items: _taskTypes.map((String type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedTaskType = newValue!);
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _hoursController,
                decoration: const InputDecoration(labelText: 'Estimated Hours to Complete'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter estimated hours';
                  if (int.tryParse(value) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_selectedDate == null
                    ? 'No Due Date Selected'
                    : 'Due Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDueDate(context),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitTask,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Save Task', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}