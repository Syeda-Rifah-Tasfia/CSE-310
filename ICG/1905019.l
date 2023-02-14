%option noyywrap

%{
#include<iostream>
#include<stdlib.h>
#include<string.h>
#include<fstream>
#include "1905019.h"
//#include "SymbolInfo.h"
#include "y.tab.h"


using namespace std;

//extern YYSTYPE yylval;

extern int id;
extern SymbolTable table1;
extern SymbolInfo *parser;
extern ofstream logout;
//extern FILE *yyin;
void yyerror(char *);

int line_count=1;
extern int err_count;


%}


digit [0-9]
letter [A-Za-z]
delim [ \t\r\f\v]
newline \n
ws [delim]+
id (_|{letter})(_|{letter}|{digit})*
integer {digit}+
number {digit}*(\.{digit}+)?(E[+-]?{digit}+)?
ADDOP [+-] 
MULOP [*/%]

%%

{delim}+	{}
{newline} {line_count++;}

"if" {
	logout << "Line# " << line_count << ": Token <IF> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "IF");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return IF;
	}
"else" {
	logout << "Line# " << line_count << ": Token <ELSE> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "ELSE");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return ELSE;
	}
"for" {
	logout << "Line# " << line_count << ": Token <FOR> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "FOR");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return FOR;
	}
"while" {
	logout << "Line# " << line_count << ": Token <WHILE> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "WHILE");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return WHILE;
	}
"int" {
	logout << "Line# " << line_count << ": Token <INT> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "INT");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return INT;
	}
"float" {
	logout << "Line# " << line_count << ": Token <FLOAT> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "FLOAT");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return FLOAT;
	}
"return" {
	logout << "Line# " << line_count << ": Token <RETURN> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "RETURN");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return RETURN;
	}
"void" {
	logout << "Line# " << line_count << ": Token <VOID> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "VOID");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return VOID;
	}
"println"	{
	logout << "Line# " << line_count << ": Token <PRINTLN> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "PRINTLN");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return PRINTLN;
}

{ADDOP} {
			logout << "Line# " << line_count << ": Token <ADDOP> Lexeme " << yytext << " found" << endl; 
			SymbolInfo *s= new  SymbolInfo(yytext, (char *)"ADDOP");
			s->setStart(line_count);
			s->setFinish(line_count);
			s->isLeaf = true;
			yylval.table = s;
			return ADDOP;
		}



{MULOP}	{
			logout << "Line# " << line_count << ": Token <MULOP> Lexeme " << yytext << " found" << endl;
			SymbolInfo *s= new  SymbolInfo(yytext, (char *)"MULOP");
			s->setStart(line_count);
			s->setFinish(line_count);
			s->isLeaf = true;
			yylval.table = s;
			return MULOP;
		}


"=" 	{
	logout << "Line# " << line_count << ": Token <ASSIGNOP> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "ASSIGNOP");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return ASSIGNOP;}

">" |
"<" |
">=" |
"<=" |
"==" |
"!=" {
		logout << "Line# " << line_count << ": Token <RELOP> Lexeme " << yytext << " found" << endl;
		SymbolInfo *s= new  SymbolInfo(yytext, (char *)"RELOP");
		s->setStart(line_count);
		s->setFinish(line_count);
		s->isLeaf = true;
		yylval.table = s;
		return RELOP;
	}

"&&"	|
"||"	{
			logout << "Line# " << line_count << ": Token <LOGICOP> Lexeme " << yytext << " found" << endl;
			SymbolInfo *s= new  SymbolInfo(yytext, (char *)"LOGICOP");
			s->setStart(line_count);
			s->setFinish(line_count);
			s->isLeaf = true;
			yylval.table = s;
			return LOGICOP;
		}
"!"		{	
	logout << "Line# " << line_count << ": Token <NOT> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "NOT");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return NOT; }


";" 	{ 
	logout << "Line# " << line_count << ": Token <SEMICOLON> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "SEMICOLON");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return SEMICOLON;
	}
"," 	{
	logout << "Line# " << line_count << ": Token <COMMA> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "COMMA");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return COMMA;
	}
"(" 	{
	logout << "Line# " << line_count << ": Token <LPAREN> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "LPAREN");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return LPAREN;
	}
")" 	{
	logout << "Line# " << line_count << ": Token <RPAREN> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "RPAREN");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return RPAREN;}
"{" 	{
	logout << "Line# " << line_count << ": Token <LCURL> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "LCURL");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return LCURL;
	}
"}" 	{
	logout << "Line# " << line_count << ": Token <RCURL> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "RCURL");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return RCURL;
	}
"[" 	{
	logout << "Line# " << line_count << ": Token <LSQUARE> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "LSQUARE");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return LTHIRD;
	}
"]" 	{
	logout << "Line# " << line_count << ": Token <RSQUARE> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "RSQUARE");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return RTHIRD;
	}
"++" 	{
	logout << "Line# " << line_count << ": Token <INCOP> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "INCOP");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return INCOP;
	}
"--" 	{
	logout << "Line# " << line_count << ": Token <DECOP> Lexeme " << yytext << " found" << endl;
	SymbolInfo *s = new SymbolInfo(yytext, "DECOP");
	s->setStart(line_count);
	s->setFinish(line_count);
	s->isLeaf = true;
	yylval.table = s;
	return DECOP;
	}



{integer}	{
				logout << "Line# " << line_count << ": Token <CONST_INT> Lexeme " << yytext << " found" << endl;
				SymbolInfo *s= new  SymbolInfo(yytext, (char *)"CONST_INT");
				s->setStart(line_count);
				s->setFinish(line_count);
				s->isLeaf = true;
				yylval.table = s;
				return CONST_INT;
			}
{number} 	{	
				logout << "Line# " << line_count << ": Token <CONST_FLOAT> Lexeme " << yytext << " found" << endl;
				SymbolInfo *s= new  SymbolInfo(yytext, (char *)"CONST_FLOAT");
				s->setStart(line_count);
				s->setFinish(line_count);
				s->isLeaf = true;
				yylval.table = s;
				return CONST_FLOAT; 
			}
{id} 		{	 
				logout << "Line# " << line_count << ": Token <ID> Lexeme " << yytext << " found" << endl;
				//SymbolInfo *s= table1.Lookup(yytext);

				SymbolInfo *s= new SymbolInfo(yytext, (char *)"ID");
				
				s->setStart(line_count);
				s->setFinish(line_count);
				s->isLeaf = true;
				yylval.table = s;
							
				return ID;
			}


%%








