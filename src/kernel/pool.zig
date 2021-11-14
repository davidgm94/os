const Pool = @This();
const Self = Pool;

fn Pool(comptime type: T) type
{
    return struct
    {
    };
}
