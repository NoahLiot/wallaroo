use "collections"
use "wallaroo/topology"


class MsgEnvelope
  let origin_tag: (Step tag | Source tag) // tag referencing upstream origin for msg
  let msg_uid: U64         // Source assigned UID; universally unique
  let frac_ids: (Array[U64] val| None) // fractional msg ids
  let seq_id: U64          // assigned by immediate upstream origin
  let route_id: U64        // assigned by immediate upstream origin

  new val create(origin_tag': (Step tag | Source tag), msg_uid': U64,
    frac_ids': (Array[U64] val| None), seq_id': U64, route_id': U64)
  =>
    origin_tag = origin_tag'
    msg_uid = msg_uid'
    frac_ids = frac_ids'
    seq_id = seq_id'
    route_id = route_id'

    
primitive HashTuple
  fun hash(t: (U64, U64)): U64 =>
    cantorPair(t)

  fun eq(t1: (U64, U64), t2: (U64, U64)): Bool =>
    cantorPair(t1) == cantorPair(t2)

  fun cantorPair(t: (U64, U64)): U64 =>
    (((t._1 + t._2) * (t._1 + t._2 + 1)) / 2 )+ t._2    

    
class HighWaterMarkTable
  """
  Keep track of a high watermark for each message coming into a step.
  We store the seq_id as assigned to a message by the upstream origin
  that sent the message.
  """
  let _hwmt: HashMap[(U64, U64), U64, HashTuple] =
    HashMap[(U64, U64), U64, HashTuple]()
  // tuple access to high watermark

  fun ref updateHighWatermark(origin_tag: U64, route_id: U64, seq_id: U64)
  =>
    try
      _hwmt.upsert((origin_tag, route_id), seq_id,
        lambda(x: U64, y: U64): U64 =>  y end)
    else
      @printf[I32]("Error upserting into _hwmt\n".cstring())      
    end

class TranslationTable
  """
  We need to be able to go from an incoming seq_id to an outgoing seq_id and
  vice versa.
  Create a new entry every time we send a message downstream.
  Remove old entries every time we receive a new low watermark.
  """
  let _inToOut: Map[U64, U64] = Map[U64, U64]()
  let _outToIn: Map[U64, U64] = Map[U64, U64]()
  
  fun ref update(in_seq_id: U64, out_seq_id: U64)
  =>
    try
      _inToOut.insert(in_seq_id, out_seq_id)
      _outToIn.insert(out_seq_id, in_seq_id)
    else
      @printf[I32]("Error inserting into translation tables\n".cstring())      
    end

  fun outToIn(out_seq_id: U64): U64
  =>
    """
    Return the incoming seq_id for a given outgoing seq_id.
    """
    try
      _outToIn(out_seq_id)
    else
      @printf[I32]("Error in outToIn\n".cstring())
      0
    end

  fun inToOut(in_seq_id: U64): U64
  =>
    """
    Return the outgoing seq_id for a given incoming seq_id.
    """
    try
      _inToOut(in_seq_id)
    else
      @printf[I32]("Error in inToOut\n".cstring())
      0
    end

  fun ref remove(out_seq_id: U64)
  =>
    try
      _inToOut.remove(_outToIn(out_seq_id))
      _outToIn.remove(out_seq_id)
    else
      @printf[I32]("Error in remove\n".cstring())
    end

class LowWaterMarkTable
  """
  Keep track of low watermark values per route as reported by downstream 
  steps.
  """
  let _lwmt: Map[U64, U64] = Map[U64, U64]()

  fun ref updateLowWatermark(route_id: U64, seq_id: U64)
  =>
    _lwmt(route_id) = seq_id


    
