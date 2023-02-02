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
ofstream tempicg;
extern int line_count;
int err_count = 0;
SymbolTable table1(11);
vector<SymbolInfo*> argList;
vector<pair<string, int>> paramListSizes;

int globalOffset = 2;

string funcs = "new_line proc\n\tpush ax\n\tpush dx\n\tmov ah,2\n\tmov dl,cr\n\tint 21h\n\tmov ah,2\n\tmov dl,lf\n\tint 21h\n\tpop dx\n\tpop ax\n\tret\nnew_line endp\nprint_output proc  ;print what is in ax\n\tpush ax\n\tpush bx\n\tpush cx\n\tpush dx\n\tpush si\n\tlea si,number\n\tmov bx,10\n\tadd si,4\n\tcmp ax,0\n\tjnge negate\n\tprint:\n\txor dx,dx\n\tdiv bx\n\tmov [si],dl\n\tadd [si],'0'\n\tdec si\n\tcmp ax,0\n\tjne print\n\tinc si\n\tlea dx,si\n\tmov ah,9\n\tint 21h\n\tpop si\n\tpop dx\n\tpop cx\n\tpop bx\n\tpop ax\n\tret\n\tnegate:\n\tpush ax\n\tmov ah,2\n\tmov dl,'-'\n\tint 21h\n\tpop ax\n\tneg ax\n\tjmp print\nprint_output endp\n";


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
			}
			else{
				error << "Line# " << line_count-1 << ": Redefinition of parameter '" << s->params[i].getName() << "'" << endl;
				err_count++;
				break;
			}
		}
		s->clearParam();
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
%type<table> compound_statement statements statement expression_statement expression logic_expression rel_expression 
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
	} compound_statement{
			logout << "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement " << endl;
			

			$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->children.push_back($7);
			$$->setStart($1->getStart());
			$$->setFinish($7->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			if($1->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}

			tempicg << $2->getName() << " PROC" << endl;
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

			tempicg << $2->getName() << " PROC" << endl;
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

 		
compound_statement : LCURL {table1.enterScope(id++); insertParams();} statements RCURL{
			logout << "compound_statement : LCURL statements RCURL  " << endl;

			$$ = new SymbolInfo("compound_statement", "LCURL statements RCURL");
			$$->children.push_back($1);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->setStart($1->getStart());
			$$->setFinish($4->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			table1.printAll(logout);
			table1.exitScope();
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
			}
			else{
				SymbolInfo *temp1 = table1.LookupCurr($3->getName());
				temp1->stackOffset = globalOffset;
				globalOffset += 2;
				tempicg << "\tSUB SP, 2" << endl;
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
			}
			else{
				SymbolInfo *temp1 = table1.LookupCurr($1->getName());
				temp1->stackOffset = globalOffset;
				globalOffset += 2;
				tempicg << "\tSUB SP, 2" << endl;
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

statements : statement{
			logout << "statements : statement  " << endl;

			$$ = new SymbolInfo("statements", "statement");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($1->getDType());
		}
		| statements statement{
			logout << "statements : statements statement  " << endl;

			$$ = new SymbolInfo("statements", "statements statement");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->setStart($1->getStart());
			$$->setFinish($2->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			//$$->sentence += $$->getName() + " : " + $1->getName() + " " + $2->getName();
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
		}
		| compound_statement{
			logout << "statement : compound_statement " << endl;

			$$ = new SymbolInfo("statement", "compound_statement");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($1->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}
		}
		| FOR LPAREN expression_statement expression_statement expression RPAREN statement{
			logout << "statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement" << endl;

			$$ = new SymbolInfo("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->children.push_back($6);
			$$->children.push_back($7);
			$$->setStart($1->getStart());
			$$->setFinish($7->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($3->getVoidFlag() == 1 || $4->getVoidFlag() == 1 || $5->getVoidFlag() == 1 || $7->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}
		}
		| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE{
			logout << "statement : IF LPAREN expression RPAREN statement " << endl;

			$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement");	
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->setStart($1->getStart());
			$$->setFinish($5->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($3->getVoidFlag() == 1 || $5->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}
		}
		| IF LPAREN expression RPAREN statement ELSE statement{
			logout << "statement : IF LPAREN expression RPAREN statement ELSE statement " << endl;

			$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement ELSE statement");	
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->children.push_back($6);
			$$->children.push_back($7);
			$$->setStart($1->getStart());
			$$->setFinish($7->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			if($3->getVoidFlag() == 1 || $5->getVoidFlag() == 1 || $7->getVoidFlag() == 1){
				$$->setVoidFlag(1);
			}
		}
		| WHILE LPAREN expression RPAREN statement{
			logout << "statement : WHILE LPAREN expression RPAREN statement" << endl;

			$$ = new SymbolInfo("statement", "WHILE LPAREN expression RPAREN statement");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->children.push_back($4);
			$$->children.push_back($5);
			$$->setStart($1->getStart());
			$$->setFinish($5->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			voidError($$, $3);
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
		}
		| RETURN expression SEMICOLON{
			logout << "statement : RETURN expression SEMICOLON" << endl;
			
			$$ = new SymbolInfo("statement", "RETURN expression SEMICOLON");
			$$->children.push_back($1);
			$$->children.push_back($2);
			$$->children.push_back($3);
			$$->setStart($1->getStart());
			$$->setFinish($3->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();
			
			$$->setDType($2->getDType());
			bool b = voidError($$, $2);
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
		} 
		;
	  
variable : ID{
			logout << "variable : ID 	 " << endl;

			$$ = new SymbolInfo("variable", "ID");
			$$->children.push_back($1);
			$$->setStart($1->getStart());
			$$->setFinish($1->getFinish());
			$$->sentence += $$->getName() + " : " + $$->getType();

			// lokup in st, if found, $$->dType = $1->dType
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

			// if(s1->getDType().compare("INT") == 0 && s2->getDType().compare("FLOAT") == 0){
			// error << "Line# " << line_count << ": Warning: possible loss of data in assignment of FLOAT to INT" << endl;
			// err_count++;
			// return true;
	
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
		}
		| rel_expression LOGICOP rel_expression {
			logout << "logic_expression : rel_expression LOGICOP rel_expression 	 	 " << endl;
			$$ = new SymbolInfo("logic_expression", "rel_expression LOGICOP rel_expression");
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
		}

		//NOT DONE YET (function call)
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
			//SymbolInfo *temp1 = table1.LookupCurr($1->getName());
			if(temp == nullptr){
				error << "Line# " << line_count << ": Undeclared function '" << $1->getName() <<"'" << endl;
				err_count++;
				argList.clear();
			}
			else{
				if(temp->getDType().compare("VOID") == 0){
					$1->setVoidFlag(1);
					$$->setVoidFlag(1); //means $$ has a void somewhere in it 
					// error << "Line# " << line_count << ": Void cannot be used in expression " << endl;
					// err_count++;
				}
				else{
					$$->setDType($1->getDType());
				}

				//error << temp->getName() << " " << temp->getType() << " " << temp->getType1() << " " << temp->getDType() << endl;
				
				{
					// int size;
					// for(int i = 0; i < paramListSizes.size(); i++){
					// 	if(paramListSizes[i].first.compare($1->getName()) == 0){
					// 		size = paramListSizes[i].second;
					// 	}
					// }
					//error << "arg: " << argList.size() << " params: " << temp->params.size() << endl;
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
	//logout.open("log.text");
	//parsetree.open("parsetree.txt");
	//error.open("error.txt");
    icg.open("code.asm");
	tempicg.open("temp.asm");

	string str = ".MODEL SMALL\n.STACK 1000H\n.DATA";
	icg << str << endl;
	icg << "\tCR EQU 0DH\n\tLF EQU 0AH\n\tnumber DB \"00000$\"" << endl;
	tempicg << ".CODE" << endl;
	//tempicg << "\tMOV AX, @DATA\n\tMOV DS, AX" << endl;
	//tempicg << "PUSH BP\n\tMOV BP, SP" << endl;
	yyin=fp;
	yyparse();
	//logout << "Total Lines: " << line_count << endl;
	//logout << "Total Errors: " << err_count << endl; 
	tempicg << funcs;
	tempicg << "END main" << endl;

	fclose(yyin);
	/* logout.close();
	parsetree.close();
	error.close(); */
    icg.close();
	tempicg.close();
	/* fclose(fp3); */
	
	return 0;
}

