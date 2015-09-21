# webuntis
Webuntis API-Wrapper for dlang

## Usage
Add this package to your dub dependencies.

## Example
```d
import webuntis;
import std.stdio;

void main()
{
	SessionConfiguration sconf = SessionConfiguration(
	    "username",
			"password",
			"server", // part before .webuntis.com Examples: melpomene or poly
			"school",
			"User Agent");
	Session s = new Session(sconf);
	s.login();
	auto classes = s.getClasses();
	foreach(class_;classes)
	{
		writeln(class_.name);
	}
}
```
