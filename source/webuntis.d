module webuntis;

import std.stdio;
import std.net.curl;
import std.json;
import std.format;
import std.conv;
import std.string;

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
			//TODO: Throw Exception
			writef("Login Error: %s\n",response["error"]["message"].str);
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
			//TODO: Throw Exception
			writef("Logout Error: %s\n",response["error"]["message"].str);
		}
	}
	private JSONValue sendRequest(JSONValue data)
	{
		string reqbody = data.toString();
		auto client = HTTP(url);
		client.addRequestHeader("Content-Type","application/json");
		client.postData = reqbody;

		if (sessionID != null)
		{
			client.addRequestHeader("Cookie",format("JSESSIONID=%s",sessionID));
		}

		// Response handling setup
		string response;
		client.onReceive = (ubyte[] data) { response = to!string(cast(char[]) data); return data.length; };

		// Starting the actual request
		try
		{
			client.perform();
		}
		catch (CurlException ex)
		{
			throw ex;
		}

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
