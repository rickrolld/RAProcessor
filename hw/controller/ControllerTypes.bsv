import Vector::*;
import RowMarshaller::*;
import FShow::*;

//Command Entry and its sub structs
typedef 16 MAX_CLAUSES;

typedef enum {SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP} CmdOp deriving (Eq,Bits);
typedef enum {SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP, MEMORY} DataLoc deriving (Eq,Bits);

typedef enum {EQ, LT, LE, GT, GE, NE} CompOp deriving (Eq,Bits);
typedef enum {COL_COL, COL_VAL} ClauseType deriving (Eq,Bits);
typedef enum {AND, OR} ClauseCon deriving (Eq,Bits);

typedef struct {
	ClauseType clauseType;
	Bit#(TLog#(MAX_COLS)) colOffset0;
	Bit#(TLog#(MAX_COLS)) colOffset1;
	CompOp op;
	Bit#(COL_WIDTH) val;
} SelClause deriving (Eq,Bits);

typedef struct {
	CmdOp op;
	RowAddr table0Addr;
	RowAddr table0numRows;
	RowAddr table0numCols;
	RowAddr outputAddr;
	
	//Specify where to get/put input/output data
	DataLoc inputSrc;
	DataLoc outputDest;

	//Select
	//Bit#(TLog#(MAX_CLAUSES)) numClauses;		//OBSOLETE
	Vector#(MAX_CLAUSES, SelClause) clauses;
	Bit#(MAX_CLAUSES) validClauseMask;
	//AND/OR connectors between clauses
	//Vector#(TSub#(MAX_CLAUSES,1), ClauseCon) con;  //OBSOLETE

	//Project
	Bit#(COL_WIDTH) colProjectMask;
	RowAddr projNumCols; //TODO NEW

	//Union/Diff/Xprod
	RowAddr table1Addr;
	RowAddr table1numRows;
	RowAddr table1numCols;
} CmdEntry deriving (Eq, Bits);

typedef enum {CONTROLLER, SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP} CycleSrc deriving (Eq,Bits);

typedef Tuple2#(CycleSrc, Bit#(64)) Cycles;

function Fmt showCmd(CmdEntry cmdEntry);
   Fmt ret = fshow("");
   ret = $format("\ncmdEntry.op=%d\n", cmdEntry.op);
   case (cmdEntry.inputSrc)
      SELECT:
      begin
	 ret = ret + $format("cmdEntry input table source: SELECT\n");
      end
      PROJECT:
      begin
	 ret = ret + $format("cmdEntry input table source: PROJECT\n");
      end
      UNION:
      begin
	 ret = ret + $format("cmdEntry input table source: UNION\n");
      end
      DIFFERENCE:
      begin
	 ret = ret + $format("cmdEntry input table source: DIFFERENCE\n");
      end
      XPROD:
      begin
	 ret = ret + $format("cmdEntry input table source: XPROD\n");
      end
      DEDUP:
      begin
	 ret = ret + $format("cmdEntry input table source: DEDUP\n");
      end
      MEMORY:
      begin
	 ret = ret + $format("cmdEntry 1st input table source: MEMORY %d rows x %d cols @ addr=%d\n", cmdEntry.table0numRows, cmdEntry.table0numCols, cmdEntry.table0Addr);
      end
   endcase
   
   case (cmdEntry.outputDest)
      SELECT:
      begin
	 ret = ret + $format("cmdEntry ouput table destination: SELECT\n");
      end
      PROJECT:
      begin
	 ret = ret + $format("cmdEntry ouput table destination: PROJECT\n");
      end
      UNION:
      begin
	 ret = ret + $format("cmdEntry ouput table destination: UNION\n");
      end
      DIFFERENCE:
      begin
	 ret = ret + $format("cmdEntry ouput table destination: DIFFERENCE\n");
      end
      XPROD:
      begin
	 ret = ret + $format("cmdEntry ouput table destination: XPROD\n");
      end
      DEDUP:
      begin
	 ret = ret + $format("cmdEntry ouput table destination: DEDUP\n");
      end
      MEMORY:
      begin
	 ret = ret + $format("cmdEntry output table destinaton: Memory addr=%d\n", cmdEntry.outputAddr);
      end
   endcase
   

   case (cmdEntry.op)
      SELECT: 
      begin
	 ret = ret + fshow("---SELECT---\n");
	 ret = ret + $format("validClauseMask: %b\n", cmdEntry.validClauseMask);
	 /*
	 for (Integer i = 0; i < valueOf(MAX_CLAUSES); i = i + 1)
	    begin

	       if ( cmdEntry.validClauseMask[i] == 1)
		  begin
		     let cl = cmdEntry.clauses[i];
		     ret = ret + $format("clause %d: ", i);
	       
		     ret = ret + (case (cl.clauseType)
				     COL_COL: fshow("type: COL_COL");
				     COL_VAL: fshow("type: COL_VAL");
				  endcase);
	       
		     ret = ret + $format("colOffset0:%d, op:%d, val:%d, colOffset1:%d\n", cl.colOffset0, cl.op, cl.val, cl.colOffset1);
	       
		     if ( i > 0 )
			begin
			   ret = ret + (case (i%4)
					   1: $format("clausecon %d: AND\n", i);
					   0: $format("clausecon %d: OR\n", i);
					endcase);
			end
		  end			  
	    end
	  */
      end
      PROJECT:
      begin
	 ret = ret + fshow("---PROJECT---\n");
	 ret = ret + $format("projNumCols = %d\n", cmdEntry.projNumCols) + $format("projectMask = %h\n", cmdEntry.colProjectMask);
      end
      UNION, DIFFERENCE, XPROD:
      begin
	 ret = ret + fshow("---UNION/DIFF/XPROD---\n");
	 ret = ret + $format("cmdEntry 2nd input table: %d rows %d cols @ addr=%d\n", cmdEntry.table1numRows, cmdEntry.table1numCols, cmdEntry.table1Addr);
      end
      DEDUP:
      begin
	 ret = ret + fshow("---DEDUP---\n");
      end
   endcase
   return ret + fshow("------------------------\n\n");
endfunction

				 
				  
			       
			       
			       



/*

enum CmdOp {SELECT, PROJECT, UNION, DIFFERENCE, XPROD, DEDUP, RENAME};
enum CompOp {EQ, LT, LE, GT, GE, NE};
enum ClauseType {COL_COL, COL_VAL};
enum ClauseCon {AND, OR};

struct SelClause {
	ClauseType clauseType;
	uint32_t colOffset0;
	uint32_t colOffset1;
	CompOp op;
	long int val;
};

struct CmdEntry {
	CmdOp op;
	uint32_t table0Addr;
	uint32_t table0numRows;
	uint32_t table0numCols;
	uint32_t outputAddr; //Addr for output table

	//Select
	uint32_t numClauses;
	SelClause clauses[MAX_CLAUSES];
	ClauseCon con[MAX_CLAUSES-1]; //AND/OR connectors between clauses

	//Project
	uint32_t colProjectMask;

	//Union/Diff/Xprod
	uint32_t table1Addr;
	uint32_t table1numRows;
	uint32_t table1numCols;


};
*/
