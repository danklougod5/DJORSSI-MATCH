import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('jobs_dump.json');
  final data = json.decode(file.readAsStringSync());
  final List<dynamic> allJobs = data;
  for(var job in allJobs.take(5)) {
    print("${job['job_title']}: ${job['tags']}");
  }
}
