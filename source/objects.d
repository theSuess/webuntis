// Objects representing the school entities

struct Teacher
{
	int id;
	string name;
	string foreName;
	string longName; // Used as lastname
	bool active;
}

struct Subject
{
	int id;
	string name;
	string longName;
	string alternateName;
	bool active;
}

struct SchoolClass
{
	int id;
	string name;
	string longName;
	bool active;
}

struct Room
{
	int id;
	string name;
	string longName;
	bool active;
}
