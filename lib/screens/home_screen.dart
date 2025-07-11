import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/attendance_service.dart';
import '../widgets/home/course_card.dart';
import '../models/course_attendance.dart';
import '../widgets/appbar/app_bar.dart';
import '../widgets/home/semester_year_selector.dart';
import '../services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  final SettingsService settingsService;

  const HomeScreen({super.key, required this.settingsService});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AttendanceService _service = AttendanceService();
  late String _selectedSemester = 'even';
  late String _selectedYear = '2024-25';
  late int _selectedPercentage;
  late Future<List<Course>> _courses;
  late Future<Map<String, CourseAttendance>> _attendances;

  @override
  void initState() {
    super.initState();
    _selectedPercentage = widget.settingsService.targetPercentageNotifier.value;
    _refreshData();
    
    // Listen for changes to the target percentage
    widget.settingsService.targetPercentageNotifier.addListener(_handlePercentageChange);
  }

  void _handlePercentageChange() {
    setState(() {
      _selectedPercentage = widget.settingsService.targetPercentageNotifier.value;
    });
  }

  @override
  void dispose() {
    widget.settingsService.targetPercentageNotifier.removeListener(_handlePercentageChange);
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _courses = _service.fetchCourses(_selectedSemester, _selectedYear);
      _attendances = _service.fetchCourseAttendances(_selectedSemester, _selectedYear);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: Colors.white,
        backgroundColor: Colors.black,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSemesterYearSelector(),
              const SizedBox(height: 20),
              FutureBuilder<List<Course>>(
                future: _courses,
                builder: (ctx, snapCourses) {
                  return FutureBuilder<Map<String, CourseAttendance>>(
                    future: _attendances,
                    builder: (ctx2, snapAttend) {
                      if (!snapCourses.hasData || !snapAttend.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        );
                      }
                      return _buildCourseGrid(snapCourses.data!, snapAttend.data!);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterYearSelector() {
    return SemesterYearSelector(
      selectedSemester: _selectedSemester,
      selectedYear: _selectedYear,
      onSemesterChanged: (v) => _onSelectionChanged(v, _selectedYear),
      onYearChanged: (v) => _onSelectionChanged(_selectedSemester, v),
    );
  }

  void _onSelectionChanged(String sem, String yr) async {
    final oldSem = _selectedSemester;
    final oldYr = _selectedYear;
    setState(() {
      _selectedSemester = sem;
      _selectedYear = yr;
    });

    bool error = false;
    if (sem != oldSem) {
      try {
        await _service.updateDefaultSemester(sem);
      } catch (_) {
        error = true;
        setState(() => _selectedSemester = oldSem);
      }
    }
    if (yr != oldYr) {
      try {
        await _service.updateDefaultAcademicYear(yr);
      } catch (_) {
        error = true;
        setState(() => _selectedYear = oldYr);
      }
    }
    if (!error) _refreshData();
  }

  Widget _buildCourseGrid(
    List<Course> courses,
    Map<String, CourseAttendance> attendances,
  ) {
    final crossCount = MediaQuery.of(context).size.width > 600 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 305,
      ),
      itemBuilder: (ctx, i) {
        return CourseCard(
          course: courses[i],
          attendance: attendances[courses[i].id],
          targetPercentage: _selectedPercentage,
        );
      },
    );
  }
}