import std.algorithm;
import std.json;
import objects;

struct Timetable
{
	SchoolDay[] days;
}
struct SchoolDay
{
	ClassUnit[] units;
}

struct ClassUnit
{
	Subject subject;
	Teacher teacher;
	int startTime;
	int date;
}
