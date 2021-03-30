module compiler.typecheck.core;

import compiler.symbols.check;
import compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import compiler.parsing.core;

/**
* The Parser only makes sure syntax
* is adhered to (and, well, partially)
* as it would allow string+string
* for example
*
*/
public final class TypeChecker
{
    private Module modulle;

    this(Module modulle)
    {
        this.modulle = modulle;

        writeln("Got globals: "~to!(string)(Program.getAllOf(new Variable(null, null), modulle.getStatements())));
        writeln("Got functions: "~to!(string)(Program.getAllOf(new Function(null, null, null, null), modulle.getStatements())));
        writeln("Got classes: "~to!(string)(Program.getAllOf(new Clazz(null), modulle.getStatements())));
        
        // nameResolution;
        // writeln("Res:",isValidEntity(program.getStatements(), "clazz1"));
        // writeln("Res:",isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2"));


        /* Test getEntity on Module */
        gprintln("getEntity: myModule.x: "~to!(string)(getEntity(modulle, "myModule.x")));
        gprintln("getEntity: x: "~to!(string)(getEntity(modulle, "x")));
        
        /* Test getEntity on Class */
        Container clazzEntity = cast(Container)getEntity(modulle, "clazz1");
        gprintln("getEntity: clazz1.k: "~to!(string)(getEntity(clazzEntity, "clazz1.k")));
        gprintln("getEntity: k: "~to!(string)(getEntity(clazzEntity, "k")));
        clazzEntity = cast(Container)getEntity(modulle, "myModule.clazz1");
        gprintln("getEntity: clazz1.k: "~to!(string)(getEntity(clazzEntity, "clazz1.k")));
        gprintln("getEntity: k: "~to!(string)(getEntity(clazzEntity, "myModule.clazz1.k")));

        //process();
        beginCheck();
    }

    private string[] validNames;

    private bool declareName()
    {
        return 0;
    }

    private bool isName(string nameTest)
    {
        foreach(string name; validNames)
        {
            if(cmp(nameTest, name) == 0)
            {
                return true;
            }
        }

        return false;
    }

    private void declareName(string name)
    {
        validNames ~= name;
    }

    private void beginCheck()
    {
        // checkIt(modulle.getStatements(), modulle.getName());
        checkIt(modulle);
    }

    private void checkClass(Clazz clazz)
    {

    }


    /* List of known (marked) objects */
    private Entity[] marked;

    public bool isMarkedEntity(Entity entityTest)
    {
        foreach(Entity entity; marked)
        {
            if(entity == entityTest)
            {
                return true;
            }
        }

        return false;
    }

    public void markEntity(Entity entity)
    {
        marked ~= entity;
    }

    /* Returns index or 64 1 bits */
    private ulong getStatementIndex(Statement[] statements, Statement statement)
    {
        for(ulong i = 0; i < statements.length; i++)
        {
            if(statement == statements[i])
            {
                return i;
            }
        }

        return -1;
    }


    public bool isMarkedByName(Container c, string name)
    {
        return isMarkedEntity(getEntity(c, name));
    }

    private Entity resolveWithin(Container currentContainer, string name)
    {
        Statement[] statements = currentContainer.getStatements();

        foreach(Statement statement; statements)
        {
            /* TODO: Only acuse parser not done yet */
            if(statement !is null)
            {
                Entity entity = cast(Entity)statement;

                if(entity)
                {
                    if(cmp(entity.getName(), name) == 0)
                    {
                        return entity;
                    }
                }
            }   
        }

        return null;
    }   

    private Entity resolveUp(Container currentContainer, string name)
    {
        /* If given container is null */
        if(!currentContainer)
        {
            return null;
        }

        /* Try find the Entity within the current Contaier */
        Entity entity = resolveWithin(currentContainer, name);
        gprintln("Poes");
        gprintln(entity);

        /* If we found it return it */
        if(entity)
        {
            return entity;
        }
        /* If we didn't then try go up a container */
        else
        {
            Container possibleParent = currentContainer.parentOf();

            /* Can we go up */
            if(possibleParent)
            {
                return resolveUp(possibleParent, name);
            }
            /* If the current container has no parent container */
            else
            {
                gprintln("Simply not found");
                return null;
            }
        }
    }

    private void checkClassInherit(Container c)
    {
        /* Get all types (Clazz so far) */
        Clazz[] classTypes;

        foreach(Statement statement; c.getStatements())
        {
            if(statement !is null && cast(Clazz)statement)
            {
                classTypes ~= cast(Clazz)statement;
            }
        }

        /* Process each Clazz */
        foreach(Clazz clazz; classTypes)
        {
             /* Get the current class's parent */
            string[] parentClasses = clazz.getInherit();
            gprintln("Class: "~clazz.getName()~": ParentInheritList: "~to!(string)(parentClasses));

            /* Try resolve all of these */
            foreach(string parent; parentClasses)
            {
                /* Find the named entity */
                Entity namedEntity = resolveUp(c, parent);

                /* If the entity exists */
                if(namedEntity)
                {
                    /* Check if it is a Class, if so non-null */
                    Clazz parentEntity = cast(Clazz)namedEntity;

                    /* Only inherit from class or (TODO: interfaces) */
                    if(parentEntity)
                    {
                        /* Make sure it is not myself */
                        if(parentEntity != clazz)
                        {
                            /* TODO: Add loop checking here */
                        }
                        else
                        {
                            Parser.expect("Cannot inherit from self");
                        }
                    }
                    /* Error */
                    else
                    {
                        Parser.expect("Can only inherit from classes");
                    }
                }
                /* If the entity doesn't exist then it is an error */
                else
                {
                    Parser.expect("Could not find any entity named "~parent);
                }
            }
        }

        /* Once processing is done, apply recursively */
        foreach(Clazz clazz; classTypes)
        {
            checkClassInherit(clazz);
        }


       
    }    

    private void checkClasses(Container c)
    {
        /**
        * Make sure no duplicate types (classes) defined
        * within same Container
        */
        checkClassNames(c);

        /**
        * Now that everything is neat and tidy
        * let's check class properties like inheritance
        * names
        */
        checkClassInherit(c);
    }



    /**
    * Starting from a Container c this makes sure
    * that all classes defined within that container
    * do no clash name wise
    */
    private void checkClassNames(Container c)
    {
        /* Get all types (Clazz so far) */
        Clazz[] classTypes;

        foreach(Statement statement; c.getStatements())
        {
            if(statement !is null && cast(Clazz)statement)
            {
                classTypes ~= cast(Clazz)statement;
            }
        }

        /* Declare each type */
        foreach(Clazz clazz; classTypes)
        {
            /**
            * Check if the first class found with my name is the one being
            * processed, if so then it is fine, if not then error, it has
            * been used (that identifier) already
            *
            * TODO: We cann add a check here to not allow containerName == clazz
            * TODO: Call resolveUp as we can then stop class1.class1.class1
            * Okay top would resolve first part but class1.class2.class1
            * would not be caught by that
            *
            * TODO: This will meet inner clazz1 first, we need to do another check
            */
            if(resolveUp(c, clazz.getName()) != clazz)
            {
                Parser.expect("Error defining class with same name in same container: ClassTried: "~clazz.getName()~", Container: "~c.getName());
            }
            else
            {
                /* Get the current container's parent container */
                Container parentContainer = c.parentOf();

                /* If c (container is Module) then it has no Parent */
                if(!parentContainer)
                {
                    if(cmp(c.getName(), clazz.getName()) == 0)
                    {
                        Parser.expect("Cannot use name of module, in use");
                    }
                }

                /* Find the name starting in upper cotainer */
                Entity clazzAbove = resolveUp(parentContainer, clazz.getName());

                if(!clazzAbove)
                {

                }
                else
                {
                    Parser.expect("Name in use abpve us, bad"~to!(string)(clazz));
                }

                /* If the Container's parent container is Module then we can have
                /* TODO: Check that it doesn;t equal any class up the chain */
                /* TODO: Exclude Module from this */



                // /* Still check if there is something with our name above us */
                // Container parentContainer = c.parentOf();

                // /* If at this level container we find duplicate */
                // if(resolveUp(parentContainer, clazz.getName()))
                // {
                    
                //         Parser.expect("Class with name "~clazz.getName()~" defined in class "~c.getName());
                    
                // }

                
            }
        }

        /**
        * TODO: Now we should loop through each class and do the same
        * so we have all types defined
        */
        gprintln("Defined classes: "~to!(string)(Program.getAllOf(new Clazz(""), cast(Statement[])marked)));
        
        /**
        * By now we have confirmed that within the current container
        * there are no classes defined with the same name
        *
        * We now check each Class recursively, once we are done
        * we mark the class entity as "ready" (may be referenced)
        */
        foreach(Clazz clazz; classTypes)
        {
            gprintln("Check recursive "~to!(string)(clazz), DebugType.WARNING);

            /* Check the current class's types within */
            checkClassNames(clazz);

            // checkClassInherit(clazz);
        }

       
        
        
        /*Now we should loop through each class */
        /* Once outerly everything is defined we can then handle class inheritance names */
        /* We can also then handle refereces between classes */

        // gprintln("checkTypes: ")

    }

    /* TODO clazz_21_211 , crashes */

    private void checkIt(Container c)
    {
        //gprintln("Processing at path/level: "~path, DebugType.WARNING);

        /* First we define types (so classes) */
        checkClasses(c);

        Statement[] statements = c.getStatements();
        string path = c.getName();

        foreach(Statement statement; statements)
        {
            /* If the statement is a COntainer */
            if(cast(Container)statement)
            {
                Container container = cast(Container)statement;
                string name = path~"."~container.getName();
                /* TODO: Implement */
                //checkIt()
            }
            /* If the statement is a variable declaration */
            else if(cast(Variable)statement)
            {
                Variable variable = cast(Variable)statement;
                gprintln("Declaring variable"~variable.getName());

                /**
                * To check if a name is taken we check if the current one equals the
                * first match (if so, then declare, if not, then taken)
                */
                if(getEntity(c, variable.getName()) != variable)
                {
                    Parser.expect("Duplicate name tried to be declared");
                }

                /* Check if this variable has an expression, if so check that */
                if(variable.getAssignment())
                {
                    VariableAssignment varAssign = variable.getAssignment();

                    /* TODO: Do what D does, only allow assignment of constants */
                    /* TODO: For assignments at global only allow constants */

                    Expression expression = varAssign.getExpression();
                    string type = expression.evaluateType(this, c);

                    if(!type.length)
                    {
                        Parser.expect("Expression type fetch failed: "~variable.getName());
                    }
                    gprintln("ExpressionTYpe in VarAssign: "~type);


                }

                /* Set the variable as declared */
                markEntity(variable);
            }
            /* If the statement is a function */
            else if(cast(Function)statement)
            {
                Function func = cast(Function)statement;
            }
        }
    }

    /**
    * List of currently declared variables
    */
    private Entity[] declaredVars;



    /**
    * Initialization order
    */

    /**
    * Example:
    *
    * 
    * int a;
    * int b = a;
    * int c = b;
    * Reversing must not work
    *
    * Only time it can is if the path is to something in a class as those should
    * be initialized all before variables
    */
    private void process(Statement[] statements)
    {
        /* Go through each entity and check them */

        /* TODO: Starting with x, if `int x = clacc.class.class.i` */
        /* TODO: Then we getPath from the assignment aexpressiona nd eval it */
        /**
        * TODO: The variable there cannot rely on x without it being initted, hence 
        * need for global list of declared variables
        */
    }

    /* Test name resolution */
    unittest
    {
        //assert()
    }

    /* TODO: We need a duplicate detector, maybe do this in Parser, in `parseBody` */


    // public Entity isValidEntityTop(string path)
    // {
    //     /* module.x same as x */
    //     if(cmp(path, "") == 0)
    // }


    /* TODO: Do elow functio n */
    /* TODO: I also need something to get all entities with same name */
    public bool entityCmp(Entity lhs, Entity rhs)
    {
        /* TODO: Depends on Entity */
        /* If lhs and rhs are variables then if lhs came before rhs this is true */
        return true;
    }

    /**
    * Given a Container like a Module or Class and a path
    * this will search from said container to find the Entity
    * at the given path
    *
    * If you give it class_1 and path class_1.x or x
    * they both should return the same Entity
    */
    public Entity getEntity(Container container, string path)
    {
        /* Get the Container's name */
        string containerName = container.getName();

        /* Check to see if the first item is the container's name */
        string[] pathItems = split(path, '.');
        if(cmp(pathItems[0], containerName) == 0)
        {
            /* If so, then remove it */
            path = path[indexOf(path, '.')+1..path.length];
        }

        /* Search for the Entity */
        return isValidEntity(container.getStatements(), path);
    }

    /* Path: clazz_2_1.class_2_2 */
    public Entity isValidEntity(Statement[] startingPoint, string path)
    {   /* The entity found with the matching name at the end of the path */
        // Entity foundEntity;

        /* Go through each Statement and look for Entity's */
        foreach(Statement curStatement; startingPoint)
        {
            /* Only look for Entitys */
            if(cast(Entity)curStatement !is null)
            {
                /* Current entity */
                Entity curEntity = cast(Entity)curStatement;

                /* Make sure the root of path matches current entity */
                string[] name = split(path, ".");

                /* If root does not match current entity, skip */
                if(cmp(name[0], curEntity.getName()) != 0)
                {
                    continue;
                }

                // writeln("warren g had to regulate");


                /**
                * Check if the name fully matches this entity's name
                *
                * If so, return it, a match has been found
                */
                if(cmp(path, curEntity.getName()) == 0)
                {
                    return curEntity;
                }
                /**
                * Or recurse
                */
                else
                {
                    string newPath = path[indexOf(path, '.')+1..path.length];
                    
                    /* In this case it must be some sort of container */
                    if(cast(Container)curEntity)
                    {
                        Container curContainer = cast(Container)curEntity;

                        /* Get statements */
                        Statement[] containerStatements = curContainer.getStatements();

                        /* TODO: Consider accessors? Here, Parser, where? */

                        return isValidEntity(containerStatements, newPath);
                    }
                    /* If not, error , semantics */
                    else
                    {
                        return null;
                    }
                }
            }
        }


        return null;
    }

    /**
    * This function will walk, recursively, through
    * each Statement at the top-level and generate
    * names of declared items in a global array
    *
    * This is top-level, iterative then recursive within
    * each iteration
    *
    * The point of this is to know of all symbols
    * that exist so that we can do a second pass
    * and see if symbols in use (declaration does
    * not count as "use") are infact valid references
    */
    public void nameResolution()
    {
        string[] names;

        foreach(Statement statement; Program.getAllOf(new Statement(), modulle.getStatements()))
        {
            /* TODO: Add container name */
            /* TODO: Make sure all Entity type */
            string containerName = (cast(Entity)statement).getName();
            names ~= containerName;
            string[] receivedNameSet = resolveNames(containerName, statement);
            names ~= receivedNameSet;
        }
    }

    private string[] resolveNames(string root, Statement statement)
    {
        /* If the statement is a variable then return */
        if(typeid(statement) == typeid(Variable))
        {
            return null;
        }
        /* If it is a class */
        else if(typeid(statement) == typeid(Clazz))
        {
            /* Get class's identifiers */
            
        }
        return null;
    }


    public void check()
    {
        checkDuplicateTopLevel();

        /* TODO: Process globals */
        /* TODO: Process classes */
        /* TODO: Process functions */
    }

    

    /**
    * Ensures that at the top-level there are no duplicate names
    */
    private bool checkDuplicateTopLevel()
    {
        import misc.utils;

        /* List of names travsersed so far */
        string[] names;

        /* Add all global variables */
        foreach(Variable variable; Program.getAllOf(new Variable(null, null), modulle.getStatements()))
        {
            string name = variable.getName();

            if(isPresent(names, name))
            {
                Parser.expect("Bruh duplicate var"~name);
            }
            else
            {
                names ~= variable.getName();
            }
        }

        return true;
    }
}

unittest
{
    /* TODO: Add some unit tests */
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parsing.core;

    // isUnitTest = true;

    string sourceFile = "source/tlang/testing/basic1.t";
    
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

    

        /* TODO: Open source file */
        string sourceCode = cast(string)fileBytes;
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        currentLexer.performLex();
        
      
        Parser parser = new Parser(currentLexer.getTokens());

        Module modulle = parser.parse();

        TypeChecker typeChecker = new TypeChecker(modulle);
        typeChecker.check();

        /* Test first-level resolution */
        assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz1").getName(), "clazz1")==0);

        /* Test n-level resolution */
        assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2").getName(), "clazz_2_2")==0);
        assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2.j").getName(), "j")==0);
        assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2.clazz_2_2_1").getName(), "clazz_2_2_1")==0);
        assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2").getName(), "clazz_2_2")==0);

        /* Test invalid access to j treating it as a Container (whilst it is a Variable) */
        assert(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2.j.p") is null);

        
}