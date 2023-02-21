//ICG CODE

%{
#include<iostream>
#include<cstdlib>
#include<cstring>
#include<cmath>
#include "1905019.h"
#include<fstream>
//#define YYSTYPE SymbolInfo*


using namespace std;

SymbolInfo *s = new SymbolInfo();
SymbolInfo *parser = new SymbolInfo();
string d_type = "";
int id = 1;
int yyparse(void);
int yylex(void);
extern FILE *yyin;
ofstream logout;
ofstream parsetree;
ofstream error;
ofstream icg;
ofstream opticg;
//("code.asm", ios::in | ios::out | ios::app)
ofstream tempicg;
extern int line_count;
int err_count = 0;
SymbolTable table1(11);
vector<SymbolInfo*> argList;
vector<pair<string, int>> paramListSizes;
unordered_map<int, string> umap;

int globalOffset = 0;
int paramOffset = 4;
int labelCount = 1;
int asmLineCount = 0;
int paramCount = 0;
int simpleFlag = 0;
int mainFlag = 0;
int ifFor = 0;
string label;
string retLabel;
vector<int> retFlag;

string funcs = "new_line proc\n\tpush ax\n\tpush dx\n\tmov ah,2\n\tmov dl,cr\n\tint 21h\n\tmov ah,2\n\tmov dl,lf\n\tint 21h\n\tpop dx\n\tpop ax\n\tret\nnew_line endp\nPRINT_OUTPUT PROC\n\tPUSH AX\n\tPUSH BX\n\tPUSH CX\n\tPUSH DX\n\n\t; dividend has to be in DX:AX\n\t; divisor in source, CX\n\tMOV CX, 10\n\tXOR BL, BL ; BL will store the length of number\n\tCMP AX, 0\n\tJGE STACK_OP ; number is positive\n\tMOV BH, 1; number is negative\n\tNEG AX\n\nSTACK_OP:\n\tXOR DX, DX\n\tDIV CX\n\t; quotient in AX, remainder in DX\n\tPUSH DX\n\tINC BL ; len++\n\tCMP AX, 0\n\tJG STACK_OP\n\n\tMOV AH, 02\n\tCMP BH, 1 ; if negative, print a '-' sign first\n\tJNE PRINT_LOOP\n    MOV DL, '-'\n\tINT 21H\n\nPRINT_LOOP:\n\tPOP DX\n\tXOR DH, DH\n\tADD DL, '0'\n\tINT 21H\n\tDEC BL\n\tCMP BL, 0\n\tJG PRINT_LOOP\n\n\tPOP DX\n\tPOP CX\n\tPOP BX\n\tPOP AX\n\tRET\nPRINT_OUTPUT ENDP\n";



void yyerror(char *s)
{
	//write your code
}


bool checkTable(SymbolInfo *s1){
	SymbolInfo *temp = table1.LookupCurr(s1->getName());
	if(temp == nullptr){
		return true; //Good to insert
	} 
	else{
		return false;//already exists
	}
}

void insertParams(){
	if(s->isClear() == false){
		for(int i = 0; i < s->params.size(); i++){
			if(table1.LookupCurr(s->params[i].getName()) == nullptr){
				table1.Insert(s->params[i].getName(), s->params[i].getType(), "null", s->params[i].getDType());
				if(s->params[i].getDType().compare("VOID") == 0){
					s->params[i].setVoidFlag(1);
				}
				SymbolInfo *temp = table1.LookupCurr(s->params[i].getName());
				temp->stackOffset = paramOffset;
				paramOffset += 2;
				temp->asmName = "[BP + " + to_string(temp->stackOffset) + "]";
			}
			else{
				error << "Line# " << line_count-1 << ": Redefinition of parameter '" << s->params[i].getName() << "'" << endl;
				err_count++;
				break;
			}
		}

		for(int i = 0; i < s->params.size(); i++){
			SymbolInfo *temp = table1.LookupCurr(s->params[i].getName());
			paramOffset -= 2;
			temp->stackOffset = paramOffset;
			temp->asmName = "[BP + " + to_string(temp->stackOffset) + "]";
		}
		s->clearParam();
	}
}

string newLabel(){
	string s = "L" + to_string(labelCount);
	tempicg << "L" << labelCount << ":" << endl;
	labelCount++;
	asmLineCount++; //DELETE LATER
	return s;
}

void backpatch(vector<int> v, string s){
	for(int i = 0; i < v.size(); i++){
		umap[v[i]] = s;
		cout << v[i] << " - " << s << endl;
	}
}

// void printParams(){
// 	if(s->isClear() == false){
// 		for(int i = 0; i < s->params.size(); i++){
// 			logout << s->params[i].getType() << "-->" << s->params[i].getType() << endl;
// 		}
// 		s->clearParam();
// 	}
// }

void deleteTree(SymbolInfo *p){
	if(p->isLeaf == true){
		return;
	}

	int i = 0;
	while(p->children.size() > 0){
		deleteTree(p->children[i]);
		i++;
	}

	p->children.pop_back();

	//p = nullptr;
}

void printTree(SymbolInfo *p, int h){
	
	for(int i = 0; i < h; i++){
		parsetree << " ";
	}
	if(p->isLeaf == true){
		parsetree << p->getType() << " : " << p->getName() << "	<Line: " << p->getStart() << ">" << endl;
		return;
	}
	else{
		parsetree << p->sentence << " 	<Line: " << p->getStart() << "-" << p->getFinish() << ">" << endl;
	}
	for(int i = 0; i < p->children.size(); i++){
		printTree((p->children[i]), h+1);
	}
}

bool assignError(SymbolInfo* s1, SymbolInfo* s2){
	if(s1->getDType().compare("INT") == 0 && s2->getDType().compare("FLOAT") == 0){
		error << "Line# " << line_count << ": Warning: possible loss of data in assignment of FLOAT to INT" << endl;
		err_count++;
		return true;
	}
	return false;
}

void modError(SymbolInfo* s1, SymbolInfo* s2){
	if(s1->getDType().compare("INT") != 0 || s2->getDType().compare("INT") != 0){
		error << "Line# " << line_count << ": Operands of modulus must be integers " << endl;
		err_count++;
		//return true;
	}
}

bool voidError(SymbolInfo* s0, SymbolInfo* s1){
	if(s1->getVoidFlag() == 1){
		s0->setVoidFlag(1); //means $$ has a void somewhere in it 
		return true;
	}
	else{
		return false;
	}
}

bool checkZero(SymbolInfo* s0, SymbolInfo* s1){
	if(s1->getZeroFlag() == 1){
		s0->setZeroFlag(1);
		return true;
	}
	return false;
}

void voidVarError(SymbolInfo* s1, SymbolInfo* s2){
	if(s1->getType().compare("VOID") == 0){
		error << "Line# " << line_count << ": Variable or field '" << s2->getName() << "' declared void" << endl;
		err_count++;
	}
}

void intToFloat(SymbolInfo* s0, SymbolInfo* s1, SymbolInfo* s2){
	if(s1->getDType().compare("INT") == 0 && s2->getDType().compare("FLOAT") == 0){
		s0->setDType("FLOAT");
	}

	else if(s1->getDType().compare("FLOAT") == 0 && s2->getDType().compare("INT") == 0){
		s0->setDType("FLOAT");
	}

	else if(s1->getDType().compare("FLOAT") == 0 && s2->getDType().compare("FLOAT") == 0){
		s0->setDType("FLOAT");
	}

	else{
		s0->setDType("INT");
	}
}

//void backpatch(vector<int> v, int a){}

%}



%union{
	SymbolInfo* table;
	}
	
	/* %code requires
{
#define YYSTYPE SymbolInfo*
} */
%token<table> IF ELSE FOR WHILE INT FLOAT VOID RETURN ASSIGNOP INCOP DECOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON PRINTLN
%token<table>CONST_INT
%token<table>CONST_FLOAT
%token<table>ID
%token<table>ADDOP
%token<table>MULOP
%token<table>RELOP
%token<table>LOGICOP

%type<table> start program unit var_declaration func_declaration func_definition type_specifier parameter_list 
%type<table> compound_statement M N statements statement expression_statement checkbool ifFor expression logic_expression rel_expression 
%type<table> simple_expression term unary_expression factor variable argument_list arguments non_array_subscript declaration_list
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE


//%nonassoc 


%%

start : program
	{
		logout << "start : program " << endl;
		$$ = new SymbolInfo("start", "program");
		$$->children.push_back($1);
		$$->setStart($1->getStart());
		$$->setFinish($1->getFinish());
		$$->sentence += $$->getName() + " : " + $$->getType();
		printTree($$, 0);
		// deleteTree($$);

         
	}
	;

program : program unit{
		logout << "program : program unit " << endl;
		$$ = new SymbolInfo("program", "program unit");
		$$->children.push_back($1);
		$$->children.push_back($2);
		$$->setStart($1->getStart());
		$$->setFinish($2->getFinish());
		$$->sentence += $$->getName() + " : " + $$->getType();
		// $1->getName() + " " + $2->getName();

	} 
	| unit{
		logout << "program : unit " << endl;
		$$ = new SymbolInfo("program", "unit");
		$$->children.push_back($1);
		$$->setStart($1->getStart());
		$$->setFinish($1->getFinish());
		$$->sentence += $$->getName() + " : " + $$->getType();
	}
	;
	
unit : var_declaration{
		logout << "unit : var_declaration  " << endl;
		$$ = new SymbolInfo("unit", "var_declaration");
		$$->children.push_back($1);
		$$->setStart($1->getStart());
		$$->setFinish($1->getFinish());
		$$->sentence += $$->getName() + " : " + $$->getType();
	}
    | func_declaration{
	 	logout << "unit : func_declaration " << endl;
		$$ = new SymbolInfo("unit", "func_declaration");
		$$->children.push_back($1);
		$$->setStart($1->getStart());
		$$->setFinish($1->getFinish());
		$$->sentence += $$->getName() + " : " + $$->getType(); 
	}
    | func_definition{
		logout << "unit : func_definition  " << endl;
		$$ = new SymbolInfo("unit", "func_definition");
		$$->children.push_back($1);
		$$->setStart($1->getStart());
		$$->setFinish($1->getFinish());
		$$->sentence += $$->getName() + " : " + $$->getType();
	}
    ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON{
			logout << "func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON " << endl;
			//printParams();
			bool b = checkTable($2);
			SymbolInfo *temp = table1.LookupCurr($2->getName());
			if(b == true){
				table1.Insert($2->getName(), "ID", "FUNCTION", $1->getDType());
				if($1->getVoidFlag() == 1){
					$2->setVoidFlag(1);
					$$->setVoidFlag(1);
				}
				SymbolInfo *temp1 = table1.LookupCurr($2->getName());
				//error << temp1->getName() << " " << temp1->getType() << " " << temp1->getType1() << " " << temp1->getDType() << endl;
				for(int i = 0; i < s->params.size(); i++){
					// temp1->params.push_back(s->params[i]);
					temp1->add_param(s->params[i]);
				}
				temp1->paramListSize = temp1->params.size(); 
				paramListSizes.push_back(make_pair($2->getName(), temp1->params.size()));
				//error << "size = " << temp1->params.size() << endl;
			}
			else{
				$2->setType1("FUNCTION");
				$2->setDType($1->getDType());
				// error << temp->getType1() << " " << $2->getType1() << endl;
				// error << temp->getDType() << " " << $2->getDType() << endl;
				if(temp->getType1().compare($2->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $2->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
				else if(temp->getDType().compare($2->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for '" << $2->getName() << "'" << endl;
					err_count++;
				}
			}

			$$ = new SymbolInfo("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->children.push_back($6);
			$$->setStart($1->getStart());
			$$->setFinish($6->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			s->clearParam();
		}
		| type_specifier ID LPAREN RPAREN SEMICOLON{
			logout << "func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON " << endl;
			
			
			SymbolInfo *temp = table1.LookupCurr($2->getName());
			bool b = checkTable($2);
			if(b == true){
				table1.Insert($2->getName(), "ID", "FUNCTION", $1->getDType());
				if($1->getVoidFlag() == 1){
					$2->setVoidFlag(1);
					$$->setVoidFlag(1);
				}
				SymbolInfo *temp1 = table1.LookupCurr($2->getName());
				//error << temp1->getName() << " " << temp1->getType() << " " << temp1->getType1() << " " << temp1->getDType() << endl;
				for(int i = 0; i < s->params.size(); i++){
					temp1->params.push_back(s->params[i]);
				}
				temp1->paramListSize = temp1->params.size();
				paramListSizes.push_back(make_pair($2->getName(), temp1->params.size()));
			}
			else{
				$2->setType1("FUNCTION");
				$2->setDType($1->getDType());
				if(temp->getDType().compare($2->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for '" << $2->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($2->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $2->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
			}

			$$ = new SymbolInfo("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->setStart($1->getStart());
			$$->setFinish($5->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			s->clearParam();
		}
		;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN {
		bool b = checkTable($2);
		SymbolInfo *temp = table1.LookupCurr($2->getName()); 
		if(b == true){ 
			table1.Insert($2->getName(), "ID", "FUNCTION", $1->getDType());
			if($1->getVoidFlag() == 1){
				$2->setVoidFlag(1);
			}
			SymbolInfo *temp1 = table1.LookupCurr($2->getName());
			//error << temp1->getName() << " " << temp1->getType() << " " << temp1->getType1() << " " << temp1->getDType() << endl;
			for(int i = 0; i < s->params.size(); i++){
				// temp1->params.push_back(s->params[i]);
				temp1->add_param(s->params[i]);
			}
		}
		else{
				//error << temp->params.size() << " oof " << s->params.size() <<endl;
				$2->setType1("FUNCTION");
				$2->setDType($1->getDType());
				// error << temp->getType1() << " " << $2->getType1() << endl;
				// error << temp->getDType() << " " << $2->getDType() << endl;
				//error << temp->getType1() << " " << $2->getType1() << endl;
				if(temp->getDType().compare($2->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for '" << $2->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($2->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $2->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
				else if(temp->getDType().compare($2->getDType()) == 0 && temp->getType1().compare($2->getType1()) == 0){
					
					//error << temp->getName() << " " << temp->getType() << " " << temp->getType1() << " " << temp->getDType() << endl;
					if(temp->params.size() != s->params.size()){
						error << "Line# " << line_count << ": Conflicting types for '" << $2->getName() << "'" << endl;
						err_count++;
					}
				}
		}

		SymbolInfo *temp1 = table1.Lookup($2->getName()); 
		paramCount = temp1->params.size();
		// 	for(int i = 0; i < temp1->params.size(); i++){
		// 		SymbolInfo *tempP = &temp1->params[i];
		// 		tempP->stackOffset = paramOffset;
		// 		paramOffset += 2;
		// 		tempP->asmName = "[BP + " + to_string(tempP->stackOffset) + "]";
		// 	}

		tempicg << $2->getName() << " PROC" << endl;
		asmLineCount++;
		if($2->getName().compare("main") == 0){
			tempicg << "\tMOV AX, @DATA\n\tMOV DS, AX" << endl;
			asmLineCount++;
			asmLineCount++;
		}
		tempicg << "\tPUSH BP\n\tMOV BP, SP" << endl;
		asmLineCount++;
		asmLineCount++;

		
	} compound_statement{
			logout << "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement " << endl;
			

			$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
			

			retLabel = newLabel();
			backpatch(retFlag, retLabel);
			retFlag.clear();
			cout << "retLabel " << retLabel << endl;
			tempicg << "\tMOV SP, BP" << endl;
			asmLineCount++;
			tempicg << "\tADD SP, " << globalOffset << endl;
			asmLineCount++;
			tempicg << "\tPOP BP" << endl;
			asmLineCount++;
			if($2->getName().compare("main") == 0){
				tempicg << "    MOV AX,4CH\n    INT 21H" << endl;
				asmLineCount++;
				asmLineCount++;
			}
			else{
				int x = paramCount * 2;
				tempicg << "\tRET " << x << endl;
				asmLineCount++;
				paramCount = 0;
			}
			tempicg << $2->getName() << " ENDP" << endl;
			asmLineCount++;
			globalOffset = 0;
			paramOffset = 4;

			
		}
		| type_specifier ID LPAREN RPAREN {
			bool b = checkTable($2); 
			SymbolInfo *temp = table1.LookupCurr($2->getName());
			if(b == true){ 
				table1.Insert($2->getName(), "ID", "FUNCTION", $1->getDType());
				if($1->getVoidFlag() == 1){
					$2->setVoidFlag(1);
				}
				SymbolInfo *temp1 = table1.LookupCurr($2->getName());
				//error << temp1->getName() << " " << temp1->getType() << " " << temp1->getType1() << " " << temp1->getDType() << endl;
				for(int i = 0; i < s->params.size(); i++){
					// temp1->params.push_back(s->params[i]);
					temp1->add_param(s->params[i]);
				}
			}
			else{
				$2->setType1("FUNCTION");
				$2->setDType($1->getDType());
				// error << temp->getType1() << " " << $2->getType1() << endl;
				// error << temp->getDType() << " " << $2->getDType() << endl;
				if(temp->getDType().compare($2->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for '" << $2->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($2->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $2->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
				else if(temp->getDType().compare($2->getDType()) == 0 && temp->getType1().compare($2->getType1()) == 0){
					//error << temp->getName() << " " << temp->getType() << " " << temp->getType1() << " " << temp->getDType() << endl;
					if(temp->params.size() != s->params.size()){
						error << "Line# " << line_count << ": Conflicting types for '" << $2->getName() << "'" << endl;
						err_count++;
					}
				}
			}
			tempicg << $2->getName() << " PROC" << endl;
			asmLineCount++;
			if($2->getName().compare("main") == 0){
				mainFlag = 1;
				tempicg << "\tMOV AX, @DATA\n\tMOV DS, AX" << endl;
				asmLineCount++;
				asmLineCount++;
			}
			tempicg << "\tPUSH BP\n\tMOV BP, SP" << endl;
			asmLineCount++;
			asmLineCount++;
			} compound_statement{
			logout << "func_definition : type_specifier ID LPAREN RPAREN compound_statement" << endl;
			
			$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($6);
			$$->setStart($1->getStart());
			$$->setFinish($6->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($1->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}

			//tempicg << $2->getName() << " PROC" << endl;

			retLabel = newLabel();
			backpatch(retFlag, retLabel);
			retFlag.clear();
			cout << "retLabel " << retLabel << endl;
			tempicg << "\tMOV SP, BP" << endl;
			asmLineCount++;
			tempicg << "\tADD SP, " << globalOffset << endl;
			asmLineCount++;
			tempicg << "\tPOP BP" << endl;
			asmLineCount++;
			if($2->getName().compare("main") == 0){
				tempicg << "    MOV AX,4CH\n    INT 21H" << endl;
				asmLineCount++;
				asmLineCount++;
			}
			else {
				tempicg << "\tRET" << endl;
				asmLineCount++;		
			}
			tempicg << $2->getName() << " ENDP" << endl;
			asmLineCount++;
			globalOffset = 0;
		}
 		;				


parameter_list  : parameter_list COMMA type_specifier ID{
			logout << "parameter_list  : parameter_list COMMA type_specifier ID" << endl;
			SymbolInfo temp($4->getName(), $4->getType(), $4->getType1(), d_type);
			if($3->getDType().compare("VOID") == 0){
				error << "Line# " << line_count << ": Variable or field '" << $4->getName() << "' declared void" << endl;
				err_count++;
			}
			else{
			 	s->params.push_back(temp);
			}
			
			$$ = new SymbolInfo("parameter_list", "parameter_list COMMA type_specifier ID");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->setStart($1->getStart());
			$$->setFinish($4->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			//$$->sentence += $$->getName() + " : " + $1->getName() + " " + $2->getName() + " " + $3->getName() + " " + $4->getName();
		}
		| parameter_list COMMA type_specifier{
			logout << "parameter_list  : parameter_list COMMA type_specifier" << endl;

			SymbolInfo temp("nameless", "ID", "null", d_type);
			s->params.push_back(temp);

			$$ = new SymbolInfo("parameter_list", "parameter_list COMMA type_specifier");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
//			$$->sentence += $$->getName() + " : " + $1->getName() + " " + $2->getName() + " " + $3->getName();
		}
 		| type_specifier ID{
			logout << "parameter_list  : type_specifier ID" << endl;
			//voidVarError($1, $2);
			SymbolInfo temp($2->getName(), $2->getType(), $2->getType1(), d_type);
			if($1->getDType().compare("VOID") == 0){
				error << "Line# " << line_count << ": Variable or field '" << $2->getName() << "' declared void" << endl;
				err_count++;
			}
			else{
			 	s->params.push_back(temp);
			}
			
			$$ = new SymbolInfo("parameter_list", "type_specifier ID");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			//$$->sentence += $$->getName() + " : " + $1->getName() + " " + $2->getName();

			//paramOffset
			//SymbolInfo *temp1 = temp;
		}
		| type_specifier{
			logout << "parameter_list  : type_specifier" << endl;

			SymbolInfo temp("nameless", "ID", "null", d_type);
			s->params.push_back(temp);

			$$ = new SymbolInfo("parameter_list", "type_specifier");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			//$$->sentence += $$->getName() + " : " + $1->getName();
		}
 		;

 		
compound_statement : LCURL {table1.enterScope(id++); insertParams();} statements M RCURL{
			logout << "compound_statement : LCURL statements RCURL  " << endl;

			$$ = new SymbolInfo("compound_statement", "LCURL statements RCURL");
			// $$->children.push_back($1);
			// $$->children.push_back($3);
			// $$->children.push_back($4);
			// $$->setStart($1->getStart());
			// $$->setFinish($4->getFinish());
			// $$->sentence += $$->getName() + " : " + $$->getType();

			// table1.printAll(logout);
			table1.exitScope();

			backpatch($3->nextlist, $4->label);
			// for(int i = 0; i < $3->nextlist.size(); i++){
			// 	$$->nextlist.push_back($3->nextlist[i]);
			// }
		}
 		| LCURL {table1.enterScope(id++); insertParams();} RCURL{
			logout << "compound_statement : LCURL RCURL  " << endl;

			$$ = new SymbolInfo("compound_statement", "LCURL RCURL");
			$$->children.push_back($1);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			table1.printAll(logout);
			table1.exitScope();
		}
 		;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
			//voidVarError($1, $2);
			logout << "var_declaration : type_specifier declaration_list SEMICOLON  " << endl;
			
			$$ = new SymbolInfo("var_declaration", "type_specifier declaration_list SEMICOLON");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());

		}
 		;
 		 
type_specifier	: INT{
			logout << "type_specifier	: INT " << endl;
			d_type = "INT";
			//logout << "Int start: " << $1->getStart() << endl;
			
			$$ = new SymbolInfo("type_specifier", "INT");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
		
			$$->setDType("INT");
		}
 		| FLOAT{
			logout << "type_specifier	: FLOAT " << endl;
			d_type = "FLOAT";
			
			$$ = new SymbolInfo("type_specifier", "FLOAT");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType("FLOAT");
		}
 		| VOID{
			logout << "type_specifier	: VOID" << endl;
			d_type = "VOID";

			$$ = new SymbolInfo("type_specifier", "VOID");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType("VOID");
			$$->setVoidFlag(1);
		}
 		;
 		
declaration_list : declaration_list COMMA ID{
			logout << "declaration_list : declaration_list COMMA ID  " << endl;
			bool b = checkTable($3);
			SymbolInfo *temp = table1.LookupCurr($3->getName());
			if(b == true){
				if(d_type.compare("VOID") == 0){
					error << "Line# " << line_count << ": Variable or field '" << $3->getName() << "' declared void" << endl;
					err_count++;
				}
				else{
					table1.Insert($3->getName(), "ID", $3->getType1(), d_type);
				}
			}
			else{
				if(temp->getDType().compare($3->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for'" << $3->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($3->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $3->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
			}

			$$ = new SymbolInfo("declaration_list", "declaration_list COMMA ID");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();


			if(table1.getCurrScopeID() == 1){
				icg << "\t" << $3->getName() << " DW 1 DUP (0000H)" << endl;
				SymbolInfo *temp1 = table1.LookupCurr($3->getName());
				temp1->globalFlag = 1;
				$3->globalFlag = 1;
				temp1->asmName = $3->getName();
			}
			else{
				SymbolInfo *temp1 = table1.LookupCurr($3->getName());
				globalOffset += 2;
				temp1->stackOffset = globalOffset;
				tempicg << "\tSUB SP, 2" << endl;
				asmLineCount++;
				string s = "[BP-" + to_string(temp1->stackOffset) + "]";
				temp1->asmName = s;
				//temp1->setName(s);
				//$3->setName(s);
				temp1->globalFlag = 0;
				$3->globalFlag = 0;
			}
			
		}
		| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD{
			logout << "declaration_list : declaration_list COMMA ID LSQUARE CONST_INT RSQUARE " << endl;
			bool b = checkTable($3);
			SymbolInfo *temp = table1.LookupCurr($3->getName());
			if(b == true){
				if(d_type.compare("VOID") == 0){
					error << "Line# " << line_count << ": Variable or field '" << $3->getName() << "' declared void" << endl;
					err_count++;
				}
				else{
					table1.Insert($3->getName(), "ID", "ARRAY", d_type);
				}
			}
			else{
				if(temp->getDType().compare($3->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for'" << $3->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($3->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $3->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
			}

			$$ = new SymbolInfo("declaration_list", "declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->children.push_back($6);
			$$->setStart($1->getStart());
			$$->setFinish($6->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$3->setType1("ARRAY");
			$$->setDType($3->getDType());
			$3->arraySize = stoi($5->getName());
			
			cout << "Arraysize = " << $3->arraySize << endl;

			if(table1.getCurrScopeID() == 1){
				icg << "\t" << $3->getName() << " DW " << $5->getName() << " DUP (0000H)" << endl;
				SymbolInfo *temp1 = table1.LookupCurr($3->getName());
				temp1->globalFlag = 1;
				$3->globalFlag = 1;
				temp1->asmName = $3->getName();
				temp1->arraySize = $3->arraySize;
			}
			else{
				SymbolInfo *temp1 = table1.LookupCurr($3->getName());
				int x = stoi($5->getName());
				globalOffset += x * 2;
				temp1->stackOffset = globalOffset;
				tempicg << "\tSUB SP, " << temp1->stackOffset << endl;
				asmLineCount++;
				string s = "[BP-" + to_string(temp1->stackOffset) + "]";
				temp1->asmName = s;
				//temp1->setName(s);
				//$3->setName(s);
				temp1->globalFlag = 0;
				$3->globalFlag = 0;
				temp1->arraySize = $3->arraySize;
			}
		}
		| ID{
			bool b = checkTable($1);
			SymbolInfo *temp = table1.LookupCurr($1->getName());
			if(b == true){
				if(d_type.compare("VOID") == 0){
					error << "Line# " << line_count << ": Variable or field '" << $1->getName() << "' declared void" << endl;
					err_count++;
				}
				else{
					table1.Insert($1->getName(), "ID", $1->getType1(), d_type);
				}
			}
			else{
				if(temp->getDType().compare($1->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for'" << $1->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($1->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $1->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
			}
			logout << "declaration_list : ID " << endl;
			

			$$ = new SymbolInfo("declaration_list", "ID");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());

			if(table1.getCurrScopeID() == 1){
				icg << "\t" << $1->getName() << " DW 1 DUP (0000H)" << endl;
				SymbolInfo *temp1 = table1.LookupCurr($1->getName());
				temp1->globalFlag = 1;
				$1->globalFlag = 1;
				temp1->asmName = $1->getName();
			}
			else{
				SymbolInfo *temp1 = table1.LookupCurr($1->getName());
				globalOffset += 2;
				temp1->stackOffset = globalOffset;
				tempicg << "\tSUB SP, 2" << endl;
				asmLineCount++;
				string s = "[BP-" + to_string(temp1->stackOffset) + "]";
				temp1->asmName = s;
				//temp1->setName(s);
				//$1->setName(s);
				temp1->globalFlag = 0;
				$1->globalFlag = 0;
			}
		}
		| ID LTHIRD CONST_INT RTHIRD{
			logout << "declaration_list : ID LSQUARE CONST_INT RSQUARE " << endl;
			bool b = checkTable($1);
			SymbolInfo *temp = table1.LookupCurr($1->getName());
			if(b == true){
				
				if(d_type.compare("VOID") == 0){
					error << "Line# " << line_count << ": Variable or field'" << $1->getName() << "' declared void" << endl;
				}
				else{
					table1.Insert($1->getName(), "ID", "ARRAY", d_type);
				}
			}
			else{
				if(temp->getDType().compare($1->getDType()) != 0){
					error << "Line# " << line_count << ": Conflicting types for'" << $1->getName() << "'" << endl;
					err_count++;
				}
				else if(temp->getType1().compare($1->getType1()) != 0){
					error << "Line# " << line_count << ": '" << $1->getName() << "' redeclared as different kind of symbol" << endl;
					err_count++;
				}
			}

			$$ = new SymbolInfo("declaration_list", "ID LSQUARE CONST_INT RSQUARE");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->setStart($1->getStart());
			$$->setFinish($4->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$3->setType1("ARRAY");
			$$->setDType($1->getDType());
			$1->arraySize = stoi($3->getName());
			

			if(table1.getCurrScopeID() == 1){
				icg << "\t" << $1->getName() << " DW " << $3->getName() << " DUP (0000H)" << endl;
				SymbolInfo *temp1 = table1.LookupCurr($1->getName());
				temp1->globalFlag = 1;
				$1->globalFlag = 1;
				temp1->asmName = $1->getName();
				temp1->arraySize = $1->arraySize;
			}
			else{
				SymbolInfo *temp1 = table1.LookupCurr($1->getName());
				int x = stoi($3->getName());
				globalOffset += x * 2;
				temp1->stackOffset = globalOffset;
				tempicg << "\tSUB SP, " << temp1->stackOffset << endl;
				asmLineCount++;
				string s = "[BP-" + to_string(temp1->stackOffset) + "]";
				temp1->asmName = s;
				temp1->globalFlag = 0;
				$1->globalFlag = 0;
				temp1->arraySize = $1->arraySize;
			}
		}

		//do these enter the tree? no
		| ID LTHIRD non_array_subscript RTHIRD{
			error << "Line# " << line_count << ": Array subscript is not an integer" << endl;
			err_count++;
		}
		| declaration_list COMMA ID LTHIRD non_array_subscript RTHIRD{
			error << "Line# " << line_count << ": Array subscript is not an integer" << endl;
			err_count++;
		}
		;

non_array_subscript : CONST_FLOAT{}
		| ID{}


M 	: 	{
			label = "L" + to_string(labelCount);
			labelCount++;
			$$ = new SymbolInfo();
			$$->label = label;
			tempicg << label << ":" << endl;
			asmLineCount++;
		}
		;	   

N   :   {
			$$ = new SymbolInfo();
			tempicg << "\tJMP " << endl;
			asmLineCount++;
			$$->nextlist.push_back(asmLineCount);
		}
		;

statements : statement {
			logout << "statements : statement  " << endl;

			$$ = new SymbolInfo("statements", "statement");
		

			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}
		}
		| statements M statement{
			$$ = new SymbolInfo("statements", "statements M statement");
			logout << "statements : statements statement  " << endl;

			cout << "M = " << $2->label << endl;
			backpatch($1->nextlist, $2->label);
			// tempicg << $2->label << ":" << endl;
			// asmLineCount++;

			for(int i = 0; i < $3->nextlist.size(); i++){
				$$->nextlist.push_back($3->nextlist[i]);
			}

			for(int i = 0; i < $3->truelist.size(); i++){
				$$->truelist.push_back($3->truelist[i]);
			}

			for(int i = 0; i < $3->falselist.size(); i++){
				$$->falselist.push_back($3->falselist[i]);
			}

			for(int i = 0; i < $$->nextlist.size(); i++){
				cout << "statements next " << i << " " << $$->nextlist[i] << endl;
			}
		}
	   ;
	   

statement : var_declaration{
			logout << "statement : var_declaration " << endl;

			$$ = new SymbolInfo("statement", "var_declaration");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());
			if($1->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}
		}
		| expression_statement{
			logout << "statement : expression_statement  " << endl;

			$$ = new SymbolInfo("statement", "expression_statement");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			$$->setDType($1->getDType());
			if($1->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}

			//tempicg << label << ":" << endl;
			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}
		}
		| compound_statement{
			logout << "statement : compound_statement " << endl;

			$$ = new SymbolInfo("statement", "compound_statement");
			
			//tempicg << label << ":" << endl;
			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			// for(int i = 0; i < $1->truelist.size(); i++){
			// 	$$->truelist.push_back($1->truelist[i]);
			// }

			// for(int i = 0; i < $1->falselist.size(); i++){
			// 	$$->falselist.push_back($1->falselist[i]);
			// }
		}
		| FOR LPAREN ifFor expression_statement M ifFor expression_statement M expression N RPAREN M statement N{
			logout << "statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement" << endl;

			$$ = new SymbolInfo("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");

			backpatch($7->truelist, $12->label);
			//backpatch($4->falselist, $12->label);

			for(int i = 0; i < $7->falselist.size(); i++){
				$$->nextlist.push_back($7->falselist[i]);
			}

			for(int i = 0; i < $14->nextlist.size(); i++){
				$13->nextlist.push_back($14->nextlist[i]);
			}

			backpatch($13->nextlist, $8->label);

			for(int i = 0; i < $10->nextlist.size(); i++){
				$9->nextlist.push_back($10->nextlist[i]);
			}

			backpatch($9->nextlist, $5->label);
			
		}
		| IF LPAREN expression checkbool RPAREN M statement %prec LOWER_THAN_ELSE{
			//M {/*tempicg << $5->label << ":" << endl; asmLineCount++;*/ }
			logout << "statement : IF LPAREN expression RPAREN statement " << endl;

			$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement");	
			
			//$6->label = $5->label;
			// if($6->asmFlag == 1 || $6->asmFlag == 2){
			// 	$6->nextlist.push_back(asmLineCount);
			// }

			for(int i = 0; i < $4->truelist.size(); i++){
				$3->truelist.push_back($4->truelist[i]);
			}

			for(int i = 0; i < $4->falselist.size(); i++){
				$3->falselist.push_back($4->falselist[i]);
			}

			backpatch($3->truelist, $6->label);

			for(int i = 0; i < $3->falselist.size(); i++){
				$$->nextlist.push_back($3->falselist[i]);
			}

			for(int i = 0; i < $7->nextlist.size(); i++){
				$$->nextlist.push_back($7->nextlist[i]);
			} 

			for(int i = 0; i < $$->nextlist.size(); i++){
				cout << "if next " << i << $$->nextlist[i] << endl;
			}

		}
		| IF LPAREN expression checkbool RPAREN M statement ELSE N M statement{
			logout << "statement : IF LPAREN expression RPAREN statement ELSE statement " << endl;

			$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement ELSE statement");	

			for(int i = 0; i < $4->truelist.size(); i++){
				$3->truelist.push_back($4->truelist[i]);
			}

			for(int i = 0; i < $4->falselist.size(); i++){
				$3->falselist.push_back($4->falselist[i]);
			}
			
			backpatch($3->truelist, $6->label);
			backpatch($3->falselist, $10->label);
			//if($6->asmFlag == 1 || $6->asmFlag == 2){
			//$6->nextlist.push_back(asmLineCount);
			//}
			//$3->nextlist.push_back(asmLineCount);

			for(int i = 0; i < $7->nextlist.size(); i++){
				$$->nextlist.push_back($7->nextlist[i]);
			}

			for(int i = 0; i < $9->nextlist.size(); i++){
				$$->nextlist.push_back($9->nextlist[i]);
			}

			for(int i = 0; i < $11->nextlist.size(); i++){
				$$->nextlist.push_back($11->nextlist[i]);
			}
			
		}
		| WHILE M LPAREN expression checkbool RPAREN M statement{
			logout << "statement : WHILE LPAREN expression RPAREN statement" << endl;

			$$ = new SymbolInfo("statement", "WHILE LPAREN expression RPAREN statement");
			
			for(int i = 0; i < $5->truelist.size(); i++){
				$4->truelist.push_back($5->truelist[i]);
			}

			for(int i = 0; i < $5->falselist.size(); i++){
				$4->falselist.push_back($5->falselist[i]);
			}

			backpatch($8->nextlist, $2->label);
			backpatch($4->truelist, $7->label);

			for(int i = 0; i < $4->falselist.size(); i++){
				$$->nextlist.push_back($4->falselist[i]);
			}

			tempicg << "\tJMP " << $2->label << endl;
			asmLineCount++;

		}
		| PRINTLN LPAREN ID RPAREN SEMICOLON{
			logout << "statement : PRINTLN LPAREN ID RPAREN SEMICOLON" << endl;

			$$ = new SymbolInfo("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->setStart($1->getStart());
			$$->setFinish($5->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			SymbolInfo *temp = table1.Lookup($3->getName());
			if(temp == nullptr){
				error << "Line# " << line_count << ": Undeclared variable '" << $3->getName() <<"'" << endl;
				err_count++;
			}

			//WORK TO BE DONE
			// else{
			// 	$$->setDType($3->getDType());
			// }

			//newLabel();
			//string s = 
			//tempicg << label << ":" << endl;
			//asmLineCount++;
			//backpatch($$->nextlist, label);
			tempicg << "\tMOV AX, " << temp->asmName << "\n\tCALL print_output\n\tCALL new_line\n";
			asmLineCount += 3;
			
			for(int i = 0; i < $$->nextlist.size(); i++){
				cout << "print next " << i << $$->nextlist[i] << endl;
			}
			
		}
		|RETURN expression SEMICOLON{
			logout << "statement : RETURN expression SEMICOLON" << endl;
			
			$$ = new SymbolInfo("statement", "RETURN expression SEMICOLON");
			


			// if(paramCount != 0){
			// 	int x = paramCount * 2;
			// 	tempicg << "\tRET " << x << endl;
			// 	asmLineCount++;
			// }	
			// else{
			// 	if(mainFlag == 0){
			// 		tempicg << "\tRET" << endl;
			// 		asmLineCount++;
			// 	}
			// 	else{
			// 		mainFlag = 0;
			// 	}
					
			// }
			cout << "rule retLabel " << retLabel << endl;
			if(mainFlag == 0){
				tempicg << "\tJMP " << endl;
				asmLineCount++;
				retFlag.push_back(asmLineCount);
			}
		}
		;
	  
expression_statement : SEMICOLON{
			logout << "expression_statement : SEMICOLON		" << endl;

			$$ = new SymbolInfo("expression_statement", "SEMICOLON");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
		}			
		| expression SEMICOLON{
			logout << "expression_statement : expression SEMICOLON 		 " << endl;

			$$ = new SymbolInfo("expression_statement", "expression SEMICOLON");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());

			bool b = voidError($$, $1);
			if(b == true){
				// error << "Line# " << line_count << ": Void cannot be used in expression " << endl;
				// err_count++;
			}

			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}

			if(ifFor == 0){
				tempicg << "\tPOP AX" << endl;
				asmLineCount++;
			}
			ifFor = 0;
		} 
		;
	  
variable : ID{
			logout << "variable : ID 	 " << endl;

			$$ = new SymbolInfo("variable", "ID");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			// lookup in st, if found, $$->dType = $1->dType
			SymbolInfo *temp = table1.Lookup($1->getName());
			if(temp == nullptr){
				error << "Line# " << line_count << ": Undeclared variable '" << $1->getName() <<"'" << endl;
				err_count++;
			}
			else if(temp->getDType().compare("VOID") == 0){
				$$->setVoidFlag(1);
				$1->setVoidFlag(1);
			}
			else{
				$$->setDType(temp->getDType());
			}

			// if(temp->globalFlag == 1){
			// 	$$->setName($1->getName());
			// }
			// else{
			// 	string s = "[BP-" + to_string(temp->stackOffset) + "]";
			// 	$$->setName(s);
			// }

			$$->asmName = temp->asmName;
			$$->setType("CONST_INT");
		} 		
		| ID LTHIRD expression RTHIRD {
			logout << "variable : ID LSQUARE expression RSQUARE  	 " << endl;
			
			$$ = new SymbolInfo("variable", "ID LSQUARE expression RSQUARE");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->setStart($1->getStart());
			$$->setFinish($4->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			SymbolInfo *temp = table1.Lookup($1->getName());
			if(temp == nullptr){
				error << "Line# " << line_count << ": Undeclared array '" << $1->getName() <<"'" << endl;
				err_count++;
			}
			else {
				if(temp->getDType().compare("VOID") == 0){
					$$->setVoidFlag(1);
					$1->setVoidFlag(1);
				}
				else{
					if(temp->getType1().compare("ARRAY") != 0){
						error << "Line# " << line_count << ": '" << temp->getName() << "' is not an array" << endl;
						err_count++;
					}
					else if($3->getDType().compare("INT") != 0){
						error << "Line# " << line_count << ": Array subscript is not an integer" << endl;
						err_count++;
					}
					else{
						$$->setDType(temp->getDType());
					}
				}
			}

			tempicg << "\tPOP AX" << endl;
			asmLineCount++;

			if(temp->globalFlag == 1){
				tempicg << "\tMOV SI, AX" << endl;
				asmLineCount++;
				tempicg << "\tMOV AX, " << $1->getName() << "[SI]" << endl;
				$$->asmName = $1->getName() + "[SI]";
				asmLineCount++;
				tempicg << "\tPUSH AX" << endl;
				asmLineCount++;
				$$->setType("CONST_INT");
			}
			else{
				int x = temp->stackOffset/2 - temp->arraySize + stoi($3->getName()) + 1;
				x = x * 2;
				$$->asmName = "[BP - " + to_string(x) + "]";
				$$->setType("CONST_INT");
			}
		}
	 	;

checkbool : {
	$$ = new SymbolInfo();
	if(simpleFlag == 1){
		// tempicg << "\tPOP AX" << endl;
		// asmLineCount++;
		tempicg << "\tCMP AX, 0" << endl;
		asmLineCount++;
		tempicg << "\tJE " << endl;
		asmLineCount++;
		$$->falselist.push_back(asmLineCount);
		tempicg << "\tJMP " << endl;
		asmLineCount++;
		$$->truelist.push_back(asmLineCount);
	}
	}
	;

ifFor : {
	$$ = new SymbolInfo();
	ifFor = 1;
	}
	;

 	 
expression : logic_expression	{
			logout << "expression 	: logic_expression	 " << endl;
			
			$$ = new SymbolInfo("expression", "logic_expression");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());

			bool b = voidError($$, $1);
			if(b == false){
				checkZero($$, $1);
			}

			$$->setType($1->getType());
			$$->asmName = $1->asmName;
			//$$->nextlist = $1->nextlist;
			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}

			$$->asmFlag = $1->asmFlag;
 		}
	   	| variable ASSIGNOP logic_expression{
			logout << "expression 	: variable ASSIGNOP logic_expression 		 " << endl;

			$$ = new SymbolInfo("expression", "variable ASSIGNOP logic_expression");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($1->getVoidFlag() == 1 || $3->getVoidFlag() == 1){
				$$->setVoidFlag(1);
				error << "Line# " << line_count << ": Void cannot be used in expression " << endl;
				err_count++;
			}
			else{
				bool b = assignError($1, $3);
				if(b == false){
					$$->setDType($1->getDType());
					// if($1->getDType().compare("FLOAT") && $3->getDType().compare("INT")){
					// 	$$->setDType("FLOAT");
					// }
					// else{
					// 	$$->setDType($1->getDType());
					// }
				}
			}

			
			//string s = newLabel();
			// tempicg << label << ":" << endl;
			// asmLineCount++;
			if($3->asmFlag == 1){
				string s = newLabel();
				backpatch($3->truelist, s);
			
				tempicg << "\tMOV AX, 1" << endl;
				asmLineCount++;
				tempicg << "\tJMP " << endl;
				asmLineCount++;
				$3->nextlist.push_back(asmLineCount);

				s = newLabel();
				backpatch($3->falselist, s);
				tempicg << "\tMOV AX, 0" << endl;
				asmLineCount++;

				// tempicg << "\tPUSH AX" << endl;
				// asmLineCount++;
			}
			else if($3->asmFlag == 2){
				string s = newLabel();
				// tempicg << "\tPOP AX" << endl;
				// asmLineCount++;
				// tempicg << "\tCMP AX, 0" << endl;
				// asmLineCount++;
				// tempicg << "\tJNE " << endl;
				// asmLineCount++;
				// $3->truelist.push_back(asmLineCount);

				// tempicg << "\tJMP " << endl;
				// asmLineCount++;
				// $3->falselist.push_back(asmLineCount);

				backpatch($3->truelist, s);
			
				tempicg << "\tMOV AX, 1" << endl;
				asmLineCount++;
				tempicg << "\tJMP " << endl;
				asmLineCount++;
				$3->nextlist.push_back(asmLineCount);

				s = newLabel();
				backpatch($3->falselist, s);
				tempicg << "\tMOV AX, 0" << endl;
				asmLineCount++;

				// tempicg << "\tPUSH AX" << endl;
				// asmLineCount++;
			}

			string s = newLabel();
			backpatch($3->nextlist, s);

			
			tempicg << "\tMOV " << $1->asmName << ", AX" << endl;
			asmLineCount++;
			tempicg << "\tPUSH AX" << endl;
			asmLineCount++;
			// tempicg << "\tPOP AX" << endl;
			// asmLineCount++;
			
		} 	
	   	;
			
logic_expression : rel_expression 	{
			logout << "logic_expression : rel_expression 	 " << endl;
			$$ = new SymbolInfo("logic_expression", "rel_expression");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			

			bool b = voidError($$, $1);
			if(b == false){
				$$->setDType($1->getDType());
				checkZero($$, $1);
			}

			$$->setType($1->getType());
			$$->asmName = $1->asmName;

			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}

			$$->asmFlag = $1->asmFlag;
		}
		| rel_expression {
				if($1->asmFlag == 0){
					string s = newLabel();
					tempicg << "\tPOP AX" << endl;
					asmLineCount++;
					tempicg << "\tCMP AX, 0" << endl;
					asmLineCount++;
					tempicg << "\tJNE " << endl;
					asmLineCount++;
					$1->truelist.push_back(asmLineCount);

					tempicg << "\tJMP " << endl;
					asmLineCount++;
					$1->falselist.push_back(asmLineCount);
				}
				// else{
				// 	tempicg << "\tPUSH AX" << endl;
				// 	asmLineCount++;
				// }
			} LOGICOP M rel_expression {
			logout << "logic_expression : rel_expression LOGICOP rel_expression 	 	 " << endl;
			$$ = new SymbolInfo("logic_expression", "rel_expression LOGICOP rel_expression");
	

			//newLabel();
			
			

			if($5->asmFlag == 0){
				string s = newLabel();
				tempicg << "\tPOP AX" << endl;
				asmLineCount++;
				tempicg << "\tCMP AX, 0" << endl;
				asmLineCount++;
				tempicg << "\tJNE " << endl;
				asmLineCount++;
				$5->truelist.push_back(asmLineCount);
				tempicg << "\tJMP " << endl;
				asmLineCount++;
				$5->falselist.push_back(asmLineCount);
			}	
			// else{
			// 	tempicg << "\tPUSH AX" << endl;
			// 	asmLineCount++;
			// }
			

			// tempicg << $3->label << ":" << endl;
			// asmLineCount++;
			if($3->getName().compare("||") == 0){
				backpatch($1->falselist, $4->label);
			}
			else if($3->getName().compare("&&") == 0){
				backpatch($1->truelist, $4->label);
			}


			if($3->getName().compare("||") == 0){
				for(int i = 0; i < $5->falselist.size(); i++){
					$$->falselist.push_back($5->falselist[i]);
				}

				for(int i = 0; i < $1->truelist.size(); i++){
					$$->truelist.push_back($1->truelist[i]);
				}

				for(int i = 0; i < $5->truelist.size(); i++){
					$$->truelist.push_back($5->truelist[i]);
				}
			}
			else if($3->getName().compare("&&") == 0){
				for(int i = 0; i < $5->truelist.size(); i++){
					$$->truelist.push_back($5->truelist[i]);
				}

				for(int i = 0; i < $1->falselist.size(); i++){
					$$->falselist.push_back($1->falselist[i]);
				}

				for(int i = 0; i < $5->falselist.size(); i++){
					$$->falselist.push_back($5->falselist[i]);
				}
			}


			//string s = newLabel();
			//backpatch($$->truelist, s);
			
			/*tempicg << "\tMOV AX, 1" << endl;
			asmLineCount++;
			tempicg << "\tJMP " << endl;
			asmLineCount++;
			$$->nextlist.push_back(asmLineCount);

			//s = newLabel();
			//backpatch($$->falselist, s);
			tempicg << "\tMOV AX, 0" << endl;
			asmLineCount++;*/

			$$->asmFlag = 2;
			simpleFlag = 0;
		}	
		;
			
rel_expression	: simple_expression {
			logout << "rel_expression	: simple_expression " << endl;
			$$ = new SymbolInfo("rel_expression", "simple_expression");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			

			bool b = voidError($$, $1);
			if(b == false){
				$$->setDType($1->getDType());
				checkZero($$, $1);
			}

			$$->setType($1->getType());
			$$->asmName = $1->asmName;

			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}
			
			$$->asmFlag = $1->asmFlag;
		}
		| simple_expression RELOP simple_expression{
			logout << "rel_expression	: simple_expression RELOP simple_expression	  " << endl;
			$$ = new SymbolInfo("rel_expression", "simple_expression RELOP simple_expression");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($1->getVoidFlag() == 1 || $3->getVoidFlag() == 1){
				$$->setVoidFlag(1);
				// $1->setVoidFlag(1);
				// $3->setVoidFlag(1);
			}
			else if($1->getZeroFlag() == 1 && $3->getZeroFlag() == 1){
				$$->setZeroFlag(1);
				$$->setDType("INT");
			}
			else{
				$$->setDType("INT");
			}

			

			//newLabel();
			//asmLineCount++;
			tempicg << "\tPOP AX" << endl;
			asmLineCount++;
			tempicg << "\tMOV DX, AX" << endl;
			asmLineCount++;
			tempicg << "\tPOP AX" << endl;
			tempicg << "\tCMP AX, DX" << endl;
			asmLineCount += 2;
			if($2->getName().compare("<=") == 0){
				tempicg << "\tJLE " << endl;
			}
			else if($2->getName().compare(">=") == 0){
				tempicg << "\tJGE " << endl;
			}
			else if($2->getName().compare("<") == 0){
				tempicg << "\tJL " << endl;
			}	
			else if($2->getName().compare(">") == 0){
				tempicg << "\tJG " << endl;
			}
			else if($2->getName().compare("==") == 0){
				tempicg << "\tJE " << endl;
			}
			else if($2->getName().compare("!=") == 0){
				tempicg << "\tJNE " << endl;
			}
			asmLineCount++;
			$$->truelist.push_back(asmLineCount);
			tempicg << "\tJMP " << endl;
			asmLineCount++;
			$$->falselist.push_back(asmLineCount);

			$$->asmFlag = 1;
			//string s = newLabel(); //L1
			//backpatch($$->truelist, s);
			//s = newLabel(); //L2

			//$$->asmFlag = 1;

			/*tempicg << "\tMOV AX, 1" << endl;
			asmLineCount++;
			tempicg << "\tJMP " << endl;
			asmLineCount++;
			$$->nextlist.push_back(asmLineCount);
			//s = newLabel();
			//backpatch($$->falselist, s);
			tempicg << "\tMOV AX, 0" << endl;
			asmLineCount++;*/

			// tempicg << "\tJMP " << endl;
			// asmLineCount++;
			// $$->nextlist.push_back(asmLineCount);
			
			simpleFlag = 0;
		}	
		;
				
simple_expression : term {
			logout << "simple_expression : term " << endl;
			$$ = new SymbolInfo("simple_expression", "term");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			

			bool b = voidError($$, $1);
			if(b == false){
				$$->setDType($1->getDType());
				checkZero($$, $1);
			}
			//voidError($1);

			$$->setType($1->getType());
			$$->asmName = $1->asmName;

			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}

			$$->asmFlag = $1->asmFlag;
		}
		| simple_expression ADDOP term {
			logout << "simple_expression : simple_expression ADDOP term  " << endl;
			
			$$ = new SymbolInfo("simple_expression", "simple_expression ADDOP term");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();


			if($1->getVoidFlag() == 1 || $3->getVoidFlag() == 1){
				$$->setVoidFlag(1);
				// $1->setVoidFlag(1);
				// $3->setVoidFlag(1);
			}
			else if($1->getZeroFlag() == 1 && $3->getZeroFlag() == 1){
				$$->setZeroFlag(1);
				intToFloat($$, $1, $3);
			}
			else{
				intToFloat($$, $1, $3);
			}


			tempicg << "\tPOP AX" << endl;
			asmLineCount++;
			tempicg << "\tMOV DX, AX" << endl;
			asmLineCount++;
			tempicg << "\tPOP AX" << endl;
			asmLineCount++;
			
			if($2->getName().compare("+") == 0){
				tempicg << "\tADD AX, DX" << endl; //AX + DX
				asmLineCount++;
			}
			else if($2->getName().compare("-") == 0){ 
				tempicg << "\tSUB AX, DX" << endl; //AX - DX
				asmLineCount++;
			}

			tempicg << "\tPUSH AX" << endl;
			asmLineCount++;
			$$->asmFlag = 0;
			simpleFlag = 1;
		}
		;
					
term :	unary_expression{
			logout << "term :	unary_expression " << endl;
			$$ = new SymbolInfo("term", "unary_expression");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			bool b = voidError($$, $1);
			if(b == false){
				$$->setDType($1->getDType());
			}

			checkZero($$, $1);
			//voidError($1);

			$$->setType($1->getType());
			$$->asmName = $1->asmName;

			for(int i = 0; i < $1->nextlist.size(); i++){
				$$->nextlist.push_back($1->nextlist[i]);
			}

			for(int i = 0; i < $1->truelist.size(); i++){
				$$->truelist.push_back($1->truelist[i]);
			}

			for(int i = 0; i < $1->falselist.size(); i++){
				$$->falselist.push_back($1->falselist[i]);
			}

			$$->asmFlag = $1->asmFlag;
		}
		|  term MULOP unary_expression{
			logout << "term :	term MULOP unary_expression " << endl;
			
			$$ = new SymbolInfo("term", "term MULOP unary_expression");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($2->getName().compare("/") == 0 || $2->getName().compare("%") == 0){
				if($3->getZeroFlag() == 1){
					error << "Line# " << line_count << ": Warning: division by zero i=0f=1Const=0" << endl;
					err_count++; 
				}
			}
			if($2->getName().compare("%") == 0){
					modError($1, $3);
					//intToFloat($$, $1, $3);
			}
			else{
					// if($1->getDType().compare("VOID") == 0 || $3->getDType().compare("VOID") == 0){
					// 	$$->setVoidFlag(1);
					// 	$1->setVoidFlag(1);
					// 	$3->setVoidFlag(1);
					// }
					if($1->getVoidFlag() == 1 || $3->getVoidFlag() == 1){
						$$->setVoidFlag(1);
						// $1->setVoidFlag(1);
						// $3->setVoidFlag(1);
					}
					else{
						intToFloat($$, $1, $3);
					}
			}


			tempicg << "\tPOP AX" << endl;
			tempicg << "\tMOV CX, AX" << endl;
			tempicg << "\tPOP AX" << endl;
			tempicg << "\tCWD" << endl;
			asmLineCount += 4;
			if($2->getName().compare("*") == 0){
				tempicg << "\tMUL CX" << endl; //AX * CX
				tempicg << "\tPUSH AX" << endl;
				asmLineCount += 2;
			}
			else if($2->getName().compare("%") == 0){ 
				tempicg << "\tDIV CX" << endl; //AX/CX
				tempicg << "\tMOV AX, DX" << endl;
				tempicg << "\tPUSH AX" << endl;
				asmLineCount += 3;
			}
			else if($2->getName().compare("/") == 0){ 
				tempicg << "\tDIV CX" << endl; //AX/CX
				tempicg << "\tPUSH AX" << endl;
				asmLineCount += 2;
			}

			$$->asmFlag = 0;
			simpleFlag = 1;
		}
		;

unary_expression : ADDOP unary_expression{
			logout << "unary_expression : ADDOP unary_expression" << endl;
			$$ = new SymbolInfo("unary_expression", "ADDOP unary_expression");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			bool b = voidError($$, $2);
			if(b == false){
				$$->setDType($2->getDType());
			}
			
			checkZero($$, $1);

			if($1->getName().compare("-") == 0){
				//newLabel();
				tempicg << "\tPOP AX" << endl;
				tempicg << "\tNEG AX" << endl;
				asmLineCount += 2;
				tempicg << "\tPUSH AX" << endl;
				asmLineCount++;
			}

			else if($1->getName().compare("+") == 0){
				//newLabel();
				tempicg << "\tPOP AX" << endl;
				tempicg << "\tPUSH AX" << endl;
				asmLineCount += 2;
			}

			simpleFlag = 1;
		}  


		
		| NOT unary_expression {
			logout << "unary_expression : NOT unary_expression " << endl;
			$$ = new SymbolInfo("unary_expression", "NOT unary_expression");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			bool b = voidError($$, $2);
			if(b == false){
				$$->setDType("INT");
			}
			checkZero($$, $2);

			//newLabel();
			if($2->asmFlag == 0){
				string s = newLabel();
				tempicg << "\tPOP AX" << endl;
				tempicg << "\tCMP AX, 0" << endl;
				asmLineCount += 2;
				tempicg << "\tJNE " << endl;
				asmLineCount++;
				$2->truelist.push_back(asmLineCount);
				tempicg << "\tJMP " << endl;
				asmLineCount++;
				$2->falselist.push_back(asmLineCount);				
			}
			else{
				tempicg << "\tPUSH AX" << endl;
				asmLineCount++;
			}
			

			for(int i = 0; i < $2->truelist.size(); i++){
				$$->falselist.push_back($2->truelist[i]);
			}

			for(int i = 0; i < $2->falselist.size(); i++){
				$$->truelist.push_back($2->falselist[i]);
			}

			$$->asmFlag = 2; //NOT

			// string s = newLabel();
			// backpatch($$->falselist, s);
			// tempicg << "\tMOV AX, 0" << endl;
			// asmLineCount++;
			// tempicg << "\tJMP " << endl;
			// asmLineCount++;
			// $$->nextlist.push_back(asmLineCount);

			// s = newLabel();
			// backpatch($$->truelist, s);
			// tempicg << "\tMOV AX, 1" << endl;
			// asmLineCount++;

		}
		| factor {
			logout << "unary_expression : factor " << endl;
			$$ = new SymbolInfo("unary_expression", "factor");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());

			bool b = voidError($$, $1);
			if(b == false){
				$$->setDType($1->getDType());
			}

			checkZero($$, $1);

			$$->setType($1->getType());
			$$->asmName = $1->asmName;
			$$->asmFlag = $1->asmFlag;
		}
		;
	
factor	: variable {
			logout << "factor	: variable " << endl;
			$$ = new SymbolInfo("factor", "variable");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			bool b = voidError($$, $1);
			if(b == false){
				$$->setDType($1->getDType());
			}
			//$$->setDType($1->getDType());

			$$->asmName = $1->asmName;
			$$->setType("CONST_INT");
			tempicg << "\tMOV AX, " << $1->asmName << endl;
			tempicg << "\tPUSH AX" << endl;
			asmLineCount += 2;
			$$->asmFlag = 0;
		}

		| ID LPAREN argument_list RPAREN{
			logout << "factor	: ID LPAREN argument_list RPAREN  " << endl;
			$$ = new SymbolInfo("factor", "ID LPAREN argument_list RPAREN");

			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->setStart($1->getStart());
			$$->setFinish($4->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			SymbolInfo *temp = table1.Lookup($1->getName());
			if(temp == nullptr){
				error << "Line# " << line_count << ": Undeclared function '" << $1->getName() <<"'" << endl;
				err_count++;
				argList.clear();
			}
			else{
				if(temp->getDType().compare("VOID") == 0){
					$1->setVoidFlag(1);
					$$->setVoidFlag(1); //means $$ has a void somewhere in it 
				}
				else{
					$$->setDType($1->getDType());
				}

				
				
				{
					
					if(argList.size() < temp->params.size()){
						error << "Line# " << line_count << ": Too few arguments to function '" << $1->getName() <<"'" << endl;
						err_count++;
						argList.clear();
					}
					else if(argList.size() > temp->params.size()){
						error << "Line# " << line_count << ": Too many arguments to function '" << $1->getName() <<"'" << endl;
						err_count++;
						argList.clear();
					}
					else{
						for(int i = 0; i < argList.size(); i++){
							if(argList[i]->getDType().compare(temp->params[i].getDType()) != 0){
								error << "Line# " << line_count << ": Type mismatch for argument " << i+1 << " of '" << temp->getName() <<"'" << endl;
								err_count++;
							}
						}
						argList.clear();
				}
				}
			}

			tempicg << "\tCALL " << $1->getName() << endl;
			asmLineCount++;
			tempicg << "\tPUSH AX" << endl;
			asmLineCount++;
		}
		| LPAREN expression RPAREN{
			logout << "factor	: LPAREN expression RPAREN   " << endl;
			$$ = new SymbolInfo("factor", "LPAREN expression RPAREN");

			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			bool b = voidError($$, $2);
			if(b == false){
				$$->setDType($2->getDType());
			}

			checkZero($$, $2);
			$$->asmFlag = $2->asmFlag;
			
		}
		| CONST_INT {
			logout << "factor	: CONST_INT   " << endl;
			$$ = new SymbolInfo("factor", "CONST_INT");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			

			$$->setDType("INT");
			if($1->getName().compare("0") == 0){
				$1->setZeroFlag(1);
			}
			checkZero($$, $1);

			tempicg << "\tMOV AX, " << $1->getName() << endl;
			tempicg << "\tPUSH AX" << endl;
			asmLineCount += 2;
			//$$->setType($1->getType());
			$$->asmName = $1->getName();
			$$->asmFlag = 0;
		}
		| CONST_FLOAT{
			logout << "factor	: CONST_FLOAT   " << endl;
			$$ = new SymbolInfo("factor", "CONST_FLOAT");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType("FLOAT");
			if($1->getName().compare("0") == 0 || $1->getName().compare("0.0") == 0){
				$1->setZeroFlag(1);
			}
			checkZero($$, $1);

			$$->asmFlag = 0;
		}
		| variable INCOP{
			logout << "factor	: variable INCOP   " << endl;
			$$ = new SymbolInfo("factor", "variable INCOP");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			//checkZero($$, $1);
			$$->setDType($1->getDType());

			tempicg << "\tMOV AX, " << $1->asmName << endl;
			asmLineCount++;
			tempicg << "\tPUSH AX" << endl;
			asmLineCount++;
			tempicg << "\tINC AX" << endl;
			asmLineCount++;
			tempicg << "\tMOV " << $1->asmName << ", AX" << endl;
			asmLineCount++;
			tempicg << "\tPOP AX" << endl;
			asmLineCount++;

			$$->asmFlag = 0;
			simpleFlag = 1;
		} 
		| variable DECOP{
			logout << "factor	: variable DECOP   " << endl;
			$$ = new SymbolInfo("factor", "variable DECOP");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			//checkZero($$, $1);
			$$->setDType($1->getDType());

			tempicg << "\tMOV AX, " << $1->asmName << endl;
			asmLineCount++;
			tempicg << "\tPUSH AX" << endl;
			asmLineCount++;
			tempicg << "\tDEC AX" << endl;
			asmLineCount++;
			tempicg << "\tMOV " << $1->asmName << ", AX" << endl;
			asmLineCount++;
			tempicg << "\tPOP AX" << endl;
			asmLineCount++;

			$$->asmFlag = 0;
			simpleFlag = 1;
		}
		;
	
argument_list : arguments{
			logout << "argument_list : arguments  " << endl;
			$$ = new SymbolInfo("argument_list", "arguments");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			//$$->sentence += $$->getName() + " : " + $1->getName();
		}
		|{
			logout << "argument_list : " << endl;
			$$ = new SymbolInfo("argument_list", "");
			$$->setStart(line_count);
			$$->setFinish(line_count);
			$$->sentence += $$->getName() + " : " ;
			
			
		}
		;
	
arguments : arguments COMMA logic_expression{
			logout << "arguments : arguments COMMA logic_expression " << endl;
			$$ = new SymbolInfo("arguments", "arguments COMMA logic_expression");
			// $2 = new SymbolInfo("COMMA", ",");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			SymbolInfo *temp = new SymbolInfo($3->getName(), $3->getType(), "null", $3->getDType());
			argList.push_back(temp);
		}
		| logic_expression{
			logout << "arguments : logic_expression" << endl;

			$$ = new SymbolInfo("arguments", "logic_expression");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			SymbolInfo *temp = new SymbolInfo($1->getName(), $1->getType(), "null", $1->getDType());
			argList.push_back(temp);
		}
		;


 

%%
int main(int argc,char *argv[])
{

	FILE *fp;
	if((fp = fopen(argv[1],"r"))==NULL)
	{
		printf("Cannot Open Input File.\n");
		exit(1);
	} 

	
	table1.enterScope(id++);
	logout.open("log.text");
	//parsetree.open("parsetree.txt");
	//error.open("error.txt");
    icg.open("code.asm");
	tempicg.open("temp.asm");
	opticg.open("optimized_code.asm");

	string str = ".MODEL SMALL\n.STACK 1000H\n.Data";
	icg << str << endl;
	icg << "\tCR EQU 0DH\n\tLF EQU 0AH\n\tnumber DB \"00000$\"" << endl;
	tempicg << ".CODE" << endl;
	asmLineCount++;
	
	yyin=fp;
	yyparse();
	
	tempicg << funcs;
	tempicg << "END main" << endl;
	table1.printAll(logout);
	//asmLineCount += 2;

	/* ifstream obj("temp.asm", ios::in);
	string line;
	while(getline(obj, line) && obj.eof() == 0){
		icg << line << endl;
	}  */
	fclose(yyin);
	logout.close();
	/*parsetree.close();
	error.close(); */

	ifstream obj("temp.asm");
	string line;
	int lcount = 0;
	while(getline(obj, line)){
		lcount++;
		auto it = umap.find(lcount);
		if(it != umap.end()){
			line += it->second;
		}
		icg << line << endl;
	}

	//icg << obj.rdbuf();


	ifstream obj1("optimized_code.asm");
	//string temp;
	/* vector<string> temp; 
	while(getline(obj1, line)){
		temp.push_back(line);
	}
	opticg << temp[0] << endl; */
	/* for(int i = 1; i < temp.size(); i++){
		if(temp[i-1].compare("PUSH AX") == 0 && temp[i].compare("POP AX") == 0){
			temp.erase(temp.begin() + i);
			int x = i - 1;
			temp.erase(temp.begin() + x);
		}
		else{
			opticg << temp[i] << endl;
		}
	} */
    icg.close();
	tempicg.close();
	opticg.close();
	/* fclose(fp3); */
	
	/* ifstream ifile("code.asm", ios::in);
 	
	ofstream ofile("temp.asm", ios::out | ios::app);

	tempicg.open("temp.asm"); */

	//auto it1 = umap.begin;
	for(auto it1 : umap){
		cout << it1.first << " " << it1.second << endl;
	}

	cout << "asmLineCount = " << asmLineCount << endl;
	return 0;
}

