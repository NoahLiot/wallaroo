use "buffered"
use "wallaroo/core/sink"
use "pony-kafka"

use @EncoderEncode[Pointer[U8] ref](eid: U64, did: U64, size: Pointer[U64])
use @KafkaEncoderEncode[None](eid: U64, did: U64, value: Pointer[Pointer[U8]],
  value_size: Pointer[U64], key: Pointer[Pointer[U8]], key_size: Pointer[U64],
  part_id: Pointer[I32])

class val GoEncoder
  var _encoder_id: U64

  new val create(encoder_id: U64) =>
    _encoder_id = encoder_id

  fun apply(data: GoData, wb: Writer): Array[ByteSeq] val =>
    var s: U64 = 0
    let r = recover val
      let e = @EncoderEncode(_encoder_id, data.id(), addressof s)
      let r' = Array[U8].from_cpointer(e, s.usize()).clone()
      @free(e)
      r'
    end
    wb.write(r)
    wb.done()

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_encoder_id, ComponentType.encoder())

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_encoder_id, bytes, ComponentType.encoder())

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _encoder_id = ComponentDeserialize(bytes, ComponentType.encoder())

  fun _final() =>
    RemoveComponent(_encoder_id, ComponentType.encoder())

class val GoKafkaEncoder
  var _encoder_id: U64

  new val create(encoder_id: U64) =>
    _encoder_id = encoder_id

  fun apply(data: GoData, wb: Writer):
    (Array[ByteSeq] val, (Array[ByteSeq] val | None), (None | KafkaPartitionId))
  =>
    let k_v_p: (Array[U8] val, (Array[U8] val | None), I32) = recover val
      var value_res: Pointer[U8] = Pointer[U8]
      var value_size: U64 = 0
      var key_res: Pointer[U8] = Pointer[U8]
      var key_size: U64 = 0
      var part_id: I32 = 0

      @KafkaEncoderEncode(_encoder_id, data.id(), addressof value_res,
        addressof value_size, addressof key_res, addressof key_size,
        addressof part_id)

      let value'' = Array[U8].from_cpointer(value_res, value_size.usize()).clone()

      let key'' = if key_size == 0 then
        None
      else
        Array[U8].from_cpointer(key_res, key_size.usize()).clone()
      end
      @free(value_res)
      @free(key_res)
      (value'', key'', part_id)
    end

    (let value', let key', let part_id') = k_v_p

    wb.write(value')
    let value = wb.done()

    let key = match key'
    | let key_array: Array[U8] val =>
      wb.write(key_array)
      wb.done()
    else
      None
    end

    let part_id = if part_id' == -1 then None else part_id' end

    (consume value, consume key, part_id)

    // var s: U64 = 0
    // let r = recover val
    //   let e = @EncoderEncode(_encoder_id, data.id(), addressof s)
    //   let r' = Array[U8].from_cpointer(e, s.usize()).clone()
    //   @free(e)
    //   r'
    // end
    // wb.write("HARDCODED VALUE")
    // let value = wb.done()
    // wb.write("HARDCODED KEY")
    // let key = wb.done()
    // (consume value, None)

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_encoder_id, ComponentType.encoder())

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_encoder_id, bytes, ComponentType.encoder())

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _encoder_id = ComponentDeserialize(bytes, ComponentType.encoder())

  fun _final() =>
    RemoveComponent(_encoder_id, ComponentType.encoder())
