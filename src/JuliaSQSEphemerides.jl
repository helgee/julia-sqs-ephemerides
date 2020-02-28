module JuliaSQSEphemerides

using AWSSQS

import AstroBase:
    UTCEpoch,
    VSOP87,
    earth,
    jupiter,
    mars,
    mercury,
    neptune,
    position,
    saturn,
    state,
    sun,
    uranus,
    velocity,
    venus
import AWSCore
import JSON3
import StructTypes
import UUIDs

struct EphemerisRequest
    id::UUIDs.UUID
    func::Symbol
    utc_epoch::String
    origin::Symbol
    target::Symbol
end

StructTypes.StructType(::Type{EphemerisRequest}) = StructTypes.Struct()

struct EphemerisResponse
    id::UUIDs.UUID
    vector::Vector{Float64}
end

StructTypes.StructType(::Type{EphemerisResponse}) = StructTypes.Struct()

const aws = AWSCore.aws_config(region="eu-central-1")
const req_queue = sqs_get_queue(aws, "sqs-test")
const res_queue = sqs_get_queue(aws, "sqs-test-res")
const planets = Dict(:sun=>sun,
                     :mercury=>mercury,
                     :venus=>venus,
                     :earth=>earth,
                     :mars=>mars,
                     :jupiter=>jupiter,
                     :saturn=>saturn,
                     :uranus=>uranus,
                     :neptune=>neptune)

function get_planet(name)
    name in keys(planets) || throw(ArgumentError("`$name` is not a supported planet."))
    return planets[name]
end

function get_func(func)
    if func == :position
        return position
    elseif func == :velocity
        return velocity
    elseif func == :state
        return state
    end
    throw(ArgumentError("`$func` is not a supported function."))
end

function run()
    @info "Flushing queues."
    sqs_flush(req_queue)
    sqs_flush(res_queue)
    @info "Waiting for messages."
    while true
        try
            m = sqs_receive_message(req_queue)
            m === nothing && continue
            req = JSON3.read(m[:message], EphemerisRequest)
            @info req
            target = get_planet(req.target)
            origin = get_planet(req.origin)
            epoch = UTCEpoch(req.utc_epoch)
            func = get_func(req.func)
            v = collect(Iterators.flatten(func(VSOP87(), epoch, origin, target)))
            res = EphemerisResponse(req.id, v)
            @info res
            sqs_delete_message(req_queue, m)
            json = JSON3.write(res)
            sqs_send_message(res_queue, json)
        catch err
            err isa InterruptException && rethrow(err)
            @error exception=err
        end
    end
end

function get_ephemeris(func, utc_epoch, origin, target)
    id = UUIDs.uuid1()
    req = EphemerisRequest(id, func, utc_epoch, origin, target)
    json = JSON3.write(req)
    sqs_send_message(req_queue, json)
    while true
        m = sqs_receive_message(res_queue)
        m === nothing && continue
        res = JSON3.read(m[:message], EphemerisResponse)
        res.id != id && continue
        @info res
        sqs_delete_message(res_queue, m)
        return res.vector
    end
end

end # module
