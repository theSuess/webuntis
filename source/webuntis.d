module webuntis;

import std.stdio;
import std.array;
import std.algorithm;
import std.exception;
import std.net.curl;
import std.json;
import std.format;
import std.conv;
import std.string;
import std.process;
import std.datetime;

import objects;
import timetable;

pragma(lib,"curl");

class Session
{
	private string username;
	private string password;
	private string sessionID;
	private string url;
	private string client;

	private Teacher[] teacherCache;
	private Subject[] subjectCache;

	this(SessionConfiguration conf)
	{
		this.username = conf.username;
		this.password = conf.password;
		this.url = format("https://%s.webuntis.com/WebUntis/jsonrpc.do?school=%s",conf.server,conf.school);
		this.client = conf.client;
	}
	public void login()
	{
		auto params = format("{\"user\":\"%s\",\"password\":\"%s\",\"client\":\"%s\"}",
				username,password,client);
		auto req = Request(to!string(Clock.currTime().toUnixTime()),"authenticate",params);
		auto response = sendRequest(req.toJSON());
		try
		{
			sessionID = response["result"]["sessionId"].str;
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Login Error: %s",response["error"]["message"].str));
		}
	}
	public void logout()
	{
		auto params = "{}";
		auto req = Request(to!string(Clock.currTime().toUnixTime()),"logout",params);
		auto response = sendRequest(req.toJSON());
		try
		{
			cast(void) response["result"].isNull();
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Login Error: %s",response["error"]["message"].str));
		}
	}

	public SchoolClass[] getClasses()
	{
		auto params = "{}";
		auto req = Request(to!string(Clock.currTime().toUnixTime()),"getKlassen",params);
		auto response = sendRequest(req.toJSON());
		SchoolClass[] classes;
		try
		{
			foreach(class_;response["result"].array)
			{
				auto newClass = SchoolClass(
						to!int(class_["id"].integer),
						class_["name"].str,
						class_["longName"].str,
						class_["active"].type == JSON_TYPE.TRUE
						);
				classes ~= newClass;
			}
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Classes Error: %s",response["error"]["message"].str));
		}
		return classes;
	}

	public Timetable getTimetable(int startDate,int endDate,int class_)
	{
		teacherCache = getTeachers();
		subjectCache = getSubjects();
		auto params = format("{\"id\":%s,
			\"type\":1,
			\"startDate\":\"%s\",
			\"endDate\":\"%s\"}",class_,startDate,endDate);

		auto req = Request(to!string(Clock.currTime().toUnixTime()),"getTimetable",params);
		auto response = sendRequest(req.toJSON());
		Timetable t;
		ClassUnit[] units;
		try
		{
			t = Timetable();	
			foreach(rawUnit;response["result"].array)
			{
				auto unit = ClassUnit(
						subjectCache.filter!(x => x.id == rawUnit["su"][0]["id"].integer).front,
						teacherCache.filter!(x => x.id == rawUnit["te"][0]["id"].integer).front,
						to!int(rawUnit["startTime"].integer),
						to!int(rawUnit["date"].integer)
						);
				units ~= unit;
			}
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Timetable Error: %s",response["error"]["message"].str));
		}

		bool startTimeComp(ClassUnit x, ClassUnit y) @safe pure nothrow { return x.startTime > y.startTime; }
		for (int date = startDate; date < endDate; date++)
		{
			auto dayunits = array(units.filter!(x => x.date == date));
			SchoolDay day;
			day.units ~= dayunits;
			t.days ~= day;
		}
		return t;
	}

	public Teacher[] getTeachers()
	{
		auto params = "{}";
		auto req = Request(to!string(Clock.currTime().toUnixTime()),"getTeachers",params);
		auto response = sendRequest(req.toJSON());
		Teacher[] teachers;
		try
		{
			foreach(teacher;response["result"].array)
			{
				//ID,Name,foreName,longName,active
				auto newTeacher = Teacher(
						to!int(teacher["id"].integer),
						teacher["name"].str,
						teacher["foreName"].str,
						teacher["longName"].str,
						teacher["active"].type == JSON_TYPE.TRUE
						);
				teachers ~= newTeacher;
			}
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Teachers Error: %s",response["error"]["message"].str));
		}
		return teachers;
	}

	public Subject[] getSubjects()
	{
		auto params = "{}";
		auto req = Request(to!string(Clock.currTime().toUnixTime()),"getSubjects",params);
		auto response = sendRequest(req.toJSON());
		Subject[] subjects;
		try
		{
			foreach(subject;response["result"].array)
			{
				//ID,Name,longName,alternateName,active
				auto newSubject = Subject(
						to!int(subject["id"].integer),
						subject["name"].str,
						subject["longName"].str,
						subject["alternateName"].str,
						subject["active"].type == JSON_TYPE.TRUE
						);
				subjects ~= newSubject;
			}
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Subjects Error: %s",response["error"]["message"].str));
		}
		return subjects;
	}

	public Room[] getRooms()
	{
		auto params = "{}";
		auto req = Request(to!string(Clock.currTime().toUnixTime()),"getRooms",params);
		auto response = sendRequest(req.toJSON());
		Room[] rooms;
		try
		{
			foreach(room;response["result"].array)
			{
				//ID,Name,longName,active
				auto newRoom = Room(
						to!int(room["id"].integer),
						room["name"].str,
						room["longName"].str,
						room["active"].type == JSON_TYPE.TRUE
						);
				rooms ~= newRoom;
			}
		}
		catch (JSONException ex)
		{
			throw new WebUntisException(format("Subjects Error: %s",response["error"]["message"].str));
		}
		return rooms;
	}

	private JSONValue sendRequest(JSONValue data)
	{
		string reqbody = data.toString();
		auto client = HTTP();
		client.addRequestHeader("Content-Type","application/json");
		client.postData = reqbody;

		if (sessionID != null)
		{
			client.addRequestHeader("Cookie",format("JSESSIONID=%s",sessionID));
		}

		// Response handling setup
		string response = post(url,reqbody,client).dup;
		// Parsing and returning the JSON
		return parseJSON(response);
	}
}


struct Request
{
	string id;
	string method;
	string params;
	string jsonrpc = "2.0";
	JSONValue toJSON()
	{
		string jsonString = chomp(format(
				"{
					\"id\":\"%s\",
					\"method\":\"%s\",
					\"params\": %s ,
					\"jsonrpc\":\"%s\"
				}",
				id,
				method,
				params,
				jsonrpc
				));
		JSONValue value = parseJSON(jsonString);
		return value;
	}
}

struct SessionConfiguration
{
	string username;
	string password;
	string server;
	string school;
	string client;
}

/**
	Exception thrown on Webuntis Errors
*/
class WebUntisException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}

// All Testing happens HERE
unittest
{
	SessionConfiguration sconf = SessionConfiguration(
		environment["wuuser"],
		"wrongpassword",
		environment["wuserver"],
		environment["wuschool"],
		"WebUntis API dlang wrapper");

	Session s = new Session(sconf);

	writeln("Begin of Tests");
	writeln("---------------------------------------");

	writeln("Testing method access before login");
	assertThrown!WebUntisException(s.getClasses());
	assertThrown!WebUntisException(s.getTeachers());
	assertThrown!WebUntisException(s.logout());
	writeln("OK");

	writeln("---------------------------------------");

	writeln("Testing Login with wrong password");
	assertThrown!WebUntisException(s.login());
	writeln("OK");

	writeln("---------------------------------------");

	// Setting the real password
	sconf.password = environment["wupassword"];
	s = new Session(sconf);

	writeln("Testing Login with right password");
	assertNotThrown!WebUntisException(s.login());
	writeln("OK");

	writeln("---------------------------------------");

	writeln("Testing Teachers");
	auto teachers = s.getTeachers();
	assert(teachers.length > 0);
	writef("Found %s teachers\n",teachers.length);
	writef("For Example: %s\n",teachers[$/2].longName);

	writeln("OK");

	writeln("---------------------------------------");

	writeln("Testing Subjects");
	auto subjects = s.getSubjects();
	assert(subjects.length > 0);
	writef("Found %s subjects\n",subjects.length);
	writef("For Example: %s\n",subjects[$/2].longName);

	writeln("OK");

	writeln("---------------------------------------");

	writeln("Testing Rooms");
	auto rooms = s.getRooms();
	assert(subjects.length > 0);
	writef("Found %s Rooms\n",rooms.length);
	writef("For Example: %s\n",rooms[$/2].longName);

	writeln("OK");

	writeln("---------------------------------------");

	writeln("Testing Classes");
	auto classes = s.getClasses();
	assert(classes.length > 0);
	writef("Found %s classes\n",classes.length);
	writef("For Example %s\n",classes[$/2].name);
	writeln("OK");

	writeln("---------------------------------------");

	writeln("Testing Timetable");
	auto table = s.getTimetable(20150925,20150926,37);
	writeln("OK");

	writeln("---------------------------------------");
	s.logout();
}
