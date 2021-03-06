//projection operator
import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import Connectable::*;

import OperatorCommon::*;
import RowMarshaller::*;
import ControllerTypes::*;

typedef enum {PROJ_IDLE, PROJ_WR_REQ, PROJ_PROCESS_ROW, PROJ_DONE_ROW} ProjState deriving (Eq,Bits);
				     

//module mkProjection #(ROW_ACCESS_IFC rowIfc) (OPERATOR_IFC);
(* synthesize *)
module mkProjection (UNARY_OPERATOR_IFC);

   FIFOF#(CmdEntry) cmdQ <- mkFIFOF;
   FIFO#(RowAddr) ackRows <- mkFIFO;
   FIFO#(RowReq) rowReqQ <- mkFIFO;
   FIFO#(RowBurst) wdataQ <- mkFIFO;
   FIFO#(RowBurst) wdataMemQ <- mkFIFO;
   FIFO#(RowBurst) rdataQ <- mkFIFO;
   Reg#(ProjState) state <- mkReg(PROJ_IDLE);
   //Reg#(Row) ouputBuff <- mkReg(0);
   //Reg#(TAdd#(TLog#(COL_WIDTH), 1)) rdBurstCnt <- mkReg(0);
   Reg#(Bit#(TAdd#(TLog#(COL_WIDTH), 1))) rdBurstCnt <- mkReg(0);
   Reg#(RowAddr) wrBurstCnt <- mkReg(0);
   Reg#(RowAddr) rowCnt <- mkReg(0);

   Reg#(Bit#(COL_WIDTH)) colProjMask <- mkRegU();
	
   let currCmd = cmdQ.first();
	
   rule reqRows if (state == PROJ_IDLE);
      $display("PROJECT: project accepted command");
	  if (currCmd.inputSrc == MEMORY) begin
      	$display("PROJECT: input src is MEMORY");
		  rowReqQ.enq( RowReq{
						tableAddr: currCmd.table0Addr,
						rowOffset: 0,
						//numRows: currCmd.table0numRows,
						numRows: ?,
						numCols: currCmd.table0numCols,
						reqSrc: fromInteger(valueOf(PROJECTION_BLK)), 
						reqType: REQ_ALLROWS,
						op: READ } );
      end

      rdBurstCnt <= 0;
      wrBurstCnt <= 0;
      rowCnt <= 0;
      
      $display("PROJECT: colProjMask: %b",currCmd.colProjectMask);
      colProjMask <= currCmd.colProjectMask;
      state <= PROJ_WR_REQ;
   endrule
   
   rule write_req if (state == PROJ_WR_REQ);
      $display("PROJECT: WR_REQ");
	  if (currCmd.outputDest == MEMORY) begin
      		$display("PROJECT: WR REQ TO MEMORY");
      		rowReqQ.enq( RowReq{
					tableAddr: currCmd.outputAddr,
					rowOffset: 0,
//					numRows: currCmd.table0numRows,
					numRows: ?,
					numCols: currCmd.projNumCols,
					reqSrc: fromInteger(valueOf(PROJECTION_BLK)),
					reqType: REQ_ALLROWS,
					op: WRITE });
      end

      state <= PROJ_PROCESS_ROW;
   endrule
   
   rule process_row if (state == PROJ_PROCESS_ROW);
	  // if (rdBurstCnt < fromInteger(valueOf(BURSTS_PER_ROW)) ) begin
	 // if (rdBurstCnt < currCmd.table0numCols ) begin
		   let rburst = rdataQ.first();
		   rdataQ.deq();
			$display("PROJECT: burst: %x", rburst);

			//check if we're at the end
			if (reduceAnd(rburst) == 1) begin
				cmdQ.deq();
				
				if (currCmd.outputDest == MEMORY) begin
					wdataMemQ.enq(rburst); //enq the end of table marker
				end
				else begin
					wdataQ.enq(rburst); //enq the end of table marker
				end

				ackRows.enq(rowCnt);
				$display("PROJECT: table finished");
				state <= PROJ_IDLE;
			end
			else begin
			   if ( colProjMask[rdBurstCnt] == 1) begin
					if (currCmd.outputDest == MEMORY) begin
				   		wdataMemQ.enq(rburst);
					end
					else begin
				   		wdataQ.enq(rburst);
					end
			   //   wrBurstCnt <= wrBurstCnt+1;
			   end
			   if (rdBurstCnt == truncate(currCmd.table0numCols-1) )begin
				   rdBurstCnt <= 0;
				   rowCnt <= rowCnt+1;
			   end
			   else begin
				   rdBurstCnt <= rdBurstCnt+1;
			   end
		   end
		   //circular right shift
		   //colProjMask <= {colProjMask[0], (colProjMask >> 1)[valueOf(COL_WIDTH)-2:0]};
	   //end
	   /*
	   else begin
		   rdBurstCnt <= 0;

		   rowCnt <= rowCnt+1;
		   wrBurstCnt <= 0;
		   if (rowCnt+1 >= currCmd.table0numRows) begin
			   cmdQ.deq();
			   ackRows.enq(currCmd.table0numRows);
			   state <= PROJ_IDLE;
		   end
	   end
	   */
   endrule



	//interface vector
	Vector#(NUM_UNARY_INTEROP_IN, INTEROP_CLIENT_IFC) interIn = newVector();
	for (Integer ind=0; ind < valueOf(NUM_UNARY_INTEROP_IN); ind=ind+1) begin
		interIn[ind] = 	interface INTEROP_CLIENT_IFC;
							method Action readResp(RowBurst rData) if (cmdQ.notEmpty);
								//all try to enq into rdata fifo, 
								//but really only one is active at a time
								rdataQ.enq(rData); 
							endmethod
						endinterface;
	end


	//Interface definitions. 
	interface ROW_ACCESS_CLIENT_IFC rowIfc;
		method ActionValue#(RowReq) rowReq();
			rowReqQ.deq();
			return rowReqQ.first();
		endmethod
		method Action readResp (RowBurst rData);
			rdataQ.enq(rData);
		endmethod
		method ActionValue#(RowBurst) writeData();
			wdataMemQ.deq();
			return wdataMemQ.first();
		endmethod
	endinterface 

	interface CMD_SERVER_IFC cmdIfc; 

		//interface definition
		method Action pushCommand (CmdEntry cmdEntry);
			cmdQ.enq(cmdEntry);
		endmethod

		method ActionValue#( Bit#(31) ) getAckRows();
			ackRows.deq();
			return ackRows.first();
		endmethod
	endinterface


	interface interInIfc = interIn;

	interface INTEROP_SERVER_IFC interOutIfc;
		method ActionValue#(RowBurst) readResp();
			wdataQ.deq();
			return wdataQ.first();
		endmethod
	endinterface


endmodule
