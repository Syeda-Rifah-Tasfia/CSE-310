#include <iostream>
#include <fstream>
#include <bits/stdc++.h>

using namespace std;

class SymbolInfo {
    string name;
    string type;
    string type1;
    string dType;
    SymbolInfo *next;
    int start;
    int finish;
    int voidFlag;
    int zeroFlag;
public:
    bool isLeaf;
    string sentence;
    vector<SymbolInfo*> children;
    vector<SymbolInfo> params;
    vector<int> truelist;
    vector<int> falselist;
    vector<int> nextlist;
    string label;
    int paramListSize;
    int stackOffset;
    int globalFlag;
    string asmName;

    SymbolInfo(){
        this->setName("null");
        this->setType("null");
        this->setType1("null");
        this->setDType("null");
        this->next = nullptr;
        this->sentence = "";
        isLeaf = false;
        start = 0;
        finish = 0;
        this->setVoidFlag(0);
        this->setZeroFlag(0);
        paramListSize = 0;
    }

    SymbolInfo(string name, string type){
        this->setName(name);
        this->setType(type);
        this->setType1("null");
        this->setDType("null");
        this->next = nullptr;
        this->sentence = "";
        isLeaf = false;
        start = 0;
        finish = 0;
        this->setVoidFlag(0);
        this->setZeroFlag(0);
        paramListSize = 0;
    }
    
    SymbolInfo(string name, string type, string type1){
        this->setName(name);
        this->setType(type);
        this->setType1(type1);
        this->setDType("null");
        this->next = nullptr;
        this->sentence = "";
        isLeaf = false;
        start = 0;
        finish = 0;
        this->setVoidFlag(0);
        this->setZeroFlag(0);
        paramListSize = 0;
    }

    SymbolInfo(string name, string type, string type1, string dType){
        this->setName(name);
        this->setType(type);
        this->setType1(type1);
        this->setDType(dType);
        this->next = nullptr;
        this->sentence = "";
        isLeaf = false;
        start = 0;
        finish = 0;
        this->setVoidFlag(0);
        this->setZeroFlag(0);
        paramListSize = 0;
    }

    ~SymbolInfo(){}

    void setName(string name) {
        this->name = name;
    }

    void setType(string type) {
        this->type = type;
    }

    void setType1(string type){
        type1 = type;
    }

    void add_param(SymbolInfo sym) {
        params.push_back(sym);
        cout << sym.getName() << " inserted, now size = " << params.size() << endl;
    }

    void setDType(string type) {
        this->dType = type;
    }

    void setNext(SymbolInfo *a) {
        next = a;
    }

    void setStart(int s){
        start = s;
    }

    void setFinish(int f){
        finish = f;
    }

    void setVoidFlag(int x){
        voidFlag = x;
    }

    void setZeroFlag(int x){
        zeroFlag = x;
    }

    string getName() {
        return this->name;
    }

    string getType() {
        return this->type;
    }

    string getType1(){
        return this->type1;
    }

    string getDType(){
        return this->dType;
    }

    int getStart(){
        return start;
    }

    int getFinish(){
        return finish;
    }

    int getVoidFlag(){
        return voidFlag;
    }

    int getZeroFlag(){
        return zeroFlag;
    }        

    SymbolInfo *getNext() {
        return this->next;
    }

    void clearParam(){
        // while(params.size() != 0){
        //     params.pop_back();
        // }
        params.clear();
    }

    bool isClear(){
        if(params.size() == 0)
            return true;
        else
            return false;
    }

    // bool isLeaf(){
    //     if(children.size() == 0){
    //         return true;
    //     }
    //     else
    //         return false;
    // }
};

// SymbolInfo::SymbolInfo(string name, string type) {
//     this->setName(name);
//     this->setType(type);
//     this->next = nullptr;
// }

//SymbolInfo::~SymbolInfo() {}

class ScopeTable {
    int num_buckets;
    SymbolInfo **hashTable;
    ScopeTable *parent_scope;
    int key;
    int chainCount;

    int tableId;
public:


    int getTableId() const{
        return tableId;
    }

    void setTableId(int tableId){
        ScopeTable::tableId = tableId;
    }
    //identify table
public:
    ScopeTable(int id, int bucket){
        tableId = id;
        num_buckets = bucket;
        //cout << "before id" << tableId << endl;
        //parent_scope = parent;
        this->hashTable = new SymbolInfo *[num_buckets];
        //this->chainCount = new int[num_buckets];
        //cout << "mid id" << tableId << endl;
        for (int i = 0; i < num_buckets; i++) {
            //hashTable[i]->setNext(nullptr);
            hashTable[i] = nullptr;
            //chainCount[i] = 0;
        }
        this->setParentScope(nullptr);
    }

    ~ScopeTable(){
        delete[] hashTable;
    }

    int SDBMHash(string str) {
        unsigned long long int hash = 0;
        int i = 0;
        int len = str.length();

        for (i = 0; i < len; i++) {
            hash = (str[i]) + (hash << 6) + (hash << 16) - hash;
            hash = hash ;
        }

        return hash % num_buckets;
    }

    int hash(string name) {
        return SDBMHash(name) % num_buckets;
    }

    bool Insert(string name, string type, string type1, string dType){
        int x = hash(name);
        this->setKey(x);
        int count = 1;
        //cout<< key << endl;
        //cout<< "not yet inserted" << endl;
        SymbolInfo *objP = new SymbolInfo(name, type, type1, dType);
        //objP->setDType(dType);
        SymbolInfo *b = Lookup(objP->getName());
        if (b != nullptr) {
            return false;
        }

        SymbolInfo *a = hashTable[key];
        //1--null
        if (a == nullptr) {
            //cout << "does if work?" << endl;
            objP->setNext(nullptr);
            hashTable[key] = objP;
            this->setChainCount(count);
            //cout<< "o inserted" << endl;
            //cout << name << " " << type << " " << chainCount << endl;
            return true;
        }
        count++;
        while (a->getNext() != nullptr) {
            a = a->getNext();
            count++;
        }
        //2--int->null
        objP->setNext(nullptr);
        a->setNext(objP);
        this->setChainCount(count);

        //cout<< "o inserted" << endl;
        return true;
        /*hashTable[key][chainCount[key]] = obj;
        chainCount[key]++;*/
    }

    SymbolInfo *Lookup(string name){
        int x = hash(name);
        this->setKey(x);
        int count = 1;
        SymbolInfo *a = hashTable[x];
        while (a != nullptr) {
            if (a->getName() == name) {
                this->setChainCount(count);
                return a;
            }
            a = a->getNext();
            count++;
        }
        this->setChainCount(count);
        /*for(int i = 0; i < num_buckets; i++){
            if(x == i){
                return hashTable[i];
            }
        }*/
        return a;
    }

    bool Delete(string name){
        SymbolInfo *x = Lookup(name);
        if (x == nullptr) {
            return false;
        } else {
            int x = hash(name);
            this->setKey(x);
            int count = 1;
            SymbolInfo *a = hashTable[key];
            //SymbolInfo* b = hashTable[key];
            if (a->getName() == name) {
                hashTable[x] = a->getNext();
                this->setChainCount(count);
                return true;
            }
            while (a->getNext()->getName() != name) {
                a = a->getNext();
                count++;
            }
            a->setNext(a->getNext()->getNext());
            this->setChainCount(count);
            //cout << "does a work?" << endl;
            /*while (b->getNext() != a){
                b = b->getNext();
            }
            cout << "does b work?" << endl;
            b->setNext(a->getNext());*/
            //cout << "does delete work?" << endl;

            return true;
        }
    }

    void Print(ofstream &o){
        //ofstream obj = o; 
        o << "\tScopeTable# " << this->tableId << endl;
        for (int i = 0; i < num_buckets; i++) {
            SymbolInfo *a;
            a = hashTable[i];
            if (a != nullptr) {
                o << "\t" << i + 1 << "--> ";
                while (a != nullptr) {
                    if(a->getType1() == "null"){
                        o << "<" << a->getName() << ", " << a->getDType() << "> ";
                        
                        // if(a->getDType() == "null"){
                        //     o << "<" << a->getName() << ", " << a->getType() << "> ";    
                        // }
                        // else{
                        //}
                    }
                    else {
                        o << "<" << a->getName() << ", " << a->getType1() << ", " << a->getDType() << "> ";
                        
                        // if(a->getDType() == "null"){
                        //     o << "<" << a->getName() << ", " << a->getType1() << ", " << a->getType() << "> ";    
                        // }
                        // else{
                        //}
                        //o << "<" << a->getName() << ", " << a->getType1() << ", " << a->getType() << "> ";
                    }
                    a = a->getNext();
                }
                o << endl;
            } 

        }
    }

    ScopeTable *getParentScope(){
        return parent_scope;
    }

    void setParentScope(ScopeTable *parentScope){
        parent_scope = parentScope;
    }

    void setKey(int key) {
        this->key = key;
    }

    int getKey() {
        return this->key;
    }

    void setChainCount(int cnt) {
        this->chainCount = cnt;
    }

    int getChainCount() {
        return this->chainCount;
    }
};






class SymbolTable {
    ScopeTable *currScope;
public:
    ScopeTable *getCurrScope(){
        return currScope;
    }

    void setCurrScope(ScopeTable *currScope){
        SymbolTable::currScope = currScope;
    }

private:
    int num_buckets;
    int key;
    int chainCount;
public:
    SymbolTable(int buckets) {
        num_buckets = buckets;
        currScope = nullptr;
    }

    int getCurrScopeID(){
        return currScope->getTableId();
    }

    void enterScope(int id){
        ScopeTable *obj = new ScopeTable(id, num_buckets);
        if (currScope != nullptr) {
            //cout << "\t enter id " << currScope->getTableId() << endl;
        } else {
            //cout <<"\tnull" << endl;
        }
        obj->setParentScope(currScope);
        currScope = obj;
        /*if(currScope->getParentScope() != nullptr)
            cout << "\tenter id " << currScope->getTableId() << " " << currScope->getParentScope()->getTableId() << endl;
        else
            cout << "\tenter id " << currScope->getTableId() << endl;*/
    }

    bool exitScope(){
        if (currScope->getParentScope() == nullptr) {
            return false;
        } else {
            currScope = currScope->getParentScope();
            //cout << "\t exit id " << currScope->getTableId() << endl;
            return true;
        }
    }

    bool Insert(string name, string type, string type1, string dType){
        bool b = currScope->Insert(name, type, type1, dType);
        this->setKey(currScope->getKey());
        this->setChainCount(currScope->getChainCount());
        return b;
    }

    bool Delete(string name){
        bool b = currScope->Delete(name);
        this->setKey(currScope->getKey());
        this->setChainCount(currScope->getChainCount());
        return b;
    }



    SymbolInfo *Lookup(string name){
        ScopeTable *temp = currScope;
        while (temp != nullptr) {
            SymbolInfo *x = temp->Lookup(name);
            if (x != nullptr) {
                this->setKey(temp->getKey());
                this->setChainCount(temp->getChainCount());
                // cout << "\t'" << x->getName() << "' found in ScopeTable# "
                //     << temp->getTableId() << " at position " << temp->getKey() + 1 << ", "
                //     << temp->getChainCount() << endl;
                return x;
            }
            temp = temp->getParentScope();
        }
        return nullptr;
    }

    SymbolInfo *LookupCurr(string name){
        ScopeTable *temp = currScope;
        SymbolInfo *x = temp->Lookup(name);
        if (x != nullptr) {
            this->setKey(temp->getKey());
            this->setChainCount(temp->getChainCount());
            cout << "\t'" << x->getName() << "' found in ScopeTable# "
                << temp->getTableId() << " at position " << temp->getKey() + 1 << ", "
                << temp->getChainCount() << endl;
            return x;
        }
        return nullptr;
    }

    void printCurrent(ofstream &o){
        currScope->Print(o);
    }

    void printAll(ofstream &o){
        ScopeTable *temp = currScope;
        while (temp != nullptr) {
            temp->Print(o);
            temp = temp->getParentScope();
        }
    }

    void setKey(int key) {
        this->key = key;
    }



    int getKey() {
        return this->key;
    }

    void setChainCount(int cnt) {
        this->chainCount = cnt;
    }

    int getChainCount() {
        return this->chainCount;
    }
};




// vector<string> Tokenize(string str) {
//     vector<string> tokens;

//     // stringstream class check1
//     stringstream str1(str);

//     string str2;

//     while (getline(str1, str2, ' ')) {
//         tokens.push_back(str2);
//     }


//     return tokens;
//     // Printing the token vector
//     /*for(int i = 0; i < tokens.size(); i++)
//         cout << tokens[i] << '\n';*/
// }

