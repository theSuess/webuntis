module webuntis;

import std.stdio;
import std.exception;
import std.net.curl;
import std.json;
import std.format;
import std.conv;
import std.string;
import std.process;

pragma(lib,"curl");

class Session
{
	private string username;
	private string password;
	private string sessionID;
	private string url;
	private string client;
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
		auto req = Request("1","authenticate",params);
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
		auto req = Request("2","logout",params);
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
	unittest
	{
		SessionConfiguration sconf = SessionConfiguration(
			environment["wuuser"],
			environment["wupassword"],
			environment["wuserver"],
			environment["wuschool"],
			"WebUntis API dlang wrapper");
		Session s = new Session(sconf);
		s.login();
		s.logout();

		sconf.username = "dummy";
		s = new Session(sconf);
		assertThrown!WebUntisException(s.login());
	}

	public SchoolClass[] getClasses()
	{
		auto params = "{}";
		auto req = Request("2","getKlassen",params);
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
			throw new Exception(format("Classes Error: %s",response["error"]["message"].str));
		}
		return classes;
	}
	unittest
	{
		SessionConfiguration sconf = SessionConfiguration(
			environment["wuuser"],
			environment["wupassword"],
			environment["wuserver"],
			environment["wuschool"],
			"WebUntis API dlang wrapper");
		Session s = new Session(sconf);
		s.login();
		assert(s.getClasses().length > 0);
		s.logout();
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

struct SchoolClass
{
	int id;
	string name;
	string longName;
	bool active;
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
